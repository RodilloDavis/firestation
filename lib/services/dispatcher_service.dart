import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import '../models/emergency_report.dart';

/// Thrown by [DispatcherService.acknowledgeReport] when another dispatcher
/// already claimed the report between the UI loading it and this dispatcher
/// tapping Acknowledge. [claimedByName] is the other dispatcher's name, if
/// known.
class ReportAlreadyDispatchedException implements Exception {
  final String? claimedByName;
  ReportAlreadyDispatchedException(this.claimedByName);

  @override
  String toString() => claimedByName != null
      ? 'Report already dispatched by $claimedByName'
      : 'Report already dispatched by another unit';
}

/// Thrown by [DispatcherService.acknowledgeReport] when the dispatcher
/// already has a different report Acknowledged — a dispatcher may only have
/// one active fire report at a time, and must resolve it before dispatching
/// another.
class DispatcherHasActiveReportException implements Exception {
  @override
  String toString() =>
      'You already have a fire report in progress. Resolve it before '
      'dispatching another.';
}

class DispatcherService {
  static const String _dbUrl =
      'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app/';

  // BFP only watches the fire-report node.
  static const List<String> _watchedNodes = ['fire-report'];

  // ── Stream: real-time via Firebase Realtime Database listeners ───────────
  // Each watched node gets a live `.onValue` listener, so Pending/
  // Acknowledged/Resolved changes — made from this dispatcher or any other
  // connected client — are pushed to the UI immediately, with no polling
  // delay. The merged stream is memoized so repeated calls (e.g. from
  // rebuilds) reuse the same subscriptions instead of tearing down and
  // reconnecting the listeners.
  Stream<List<EmergencyReport>>? _reportsStream;

  Stream<List<EmergencyReport>> watchReports() {
    return _reportsStream ??= _buildReportsStream();
  }

  Stream<List<EmergencyReport>> _buildReportsStream() {
    late final StreamController<List<EmergencyReport>> controller;
    final latestByNode = <String, List<EmergencyReport>>{};
    final subscriptions = <StreamSubscription>[];

    void emit() {
      final all = <EmergencyReport>[];
      for (final list in latestByNode.values) {
        all.addAll(list);
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(all);
    }

    controller = StreamController<List<EmergencyReport>>.broadcast(
      onListen: () {
        for (final node in _watchedNodes) {
          subscriptions.add(
            FirebaseDatabase.instance.ref(node).onValue.listen((event) {
              latestByNode[node] = _parseSnapshot(event.snapshot, node);
              emit();
            }, onError: (e) => debugPrint('BFP watchReports($node) error: $e')),
          );
        }
      },
      onCancel: () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
        _reportsStream = null;
      },
    );

    return controller.stream;
  }

  List<EmergencyReport> _parseSnapshot(DataSnapshot snapshot, String node) {
    final raw = snapshot.value;
    if (raw is! Map) return [];
    final reports = <EmergencyReport>[];
    raw.forEach((key, value) {
      if (value is Map) {
        reports.add(
          EmergencyReport.fromMap(
            Map<dynamic, dynamic>.from(value),
            key.toString(),
            reportLabel: node,
          ),
        );
      }
    });
    return reports;
  }

  // ── Acknowledge → sets "Acknowledged" ─────────────────────────────────────
  // Status lifecycle: Pending → Acknowledged → Resolved
  //
  // Two atomic claims happen here, in order:
  //  1. The dispatcher's single active-report "slot" at
  //     /BFPActiveReport/{dispatcherId} — only succeeds if the dispatcher
  //     doesn't already have one, enforcing "one dispatched fire report per
  //     dispatcher at a time".
  //  2. The report itself — only succeeds while it's still Pending, so two
  //     dispatchers tapping Acknowledge on the same report at nearly the
  //     same moment can't both win it.
  // If step 2 fails after step 1 succeeded, step 1's claim is rolled back —
  // the dispatcher didn't actually end up with a report, so their slot must
  // stay free.
  Future<void> acknowledgeReport(
    String reportId, {
    String reportLabel = 'fire-report',
    required String dispatcherId,
    required String dispatcherName,
  }) async {
    const newStatus = 'Acknowledged';
    final now = DateTime.now().toIso8601String();

    final slotRef = FirebaseDatabase.instance.ref(
      'BFPActiveReport/$dispatcherId',
    );
    final slotResult = await slotRef.runTransaction((Object? data) {
      if (data != null) return Transaction.abort();
      return Transaction.success({
        'ReportId': reportId,
        'ReportLabel': reportLabel,
        'ClaimedAt': now,
      });
    });

    if (!slotResult.committed) {
      throw DispatcherHasActiveReportException();
    }

    String? claimedByName;
    final ref = FirebaseDatabase.instance.ref('$reportLabel/$reportId');
    final result = await ref.runTransaction((Object? data) {
      if (data == null || data is! Map) return Transaction.abort();
      final current = Map<String, dynamic>.from(data);
      final currentStatus = current['Status']?.toString() ?? 'Pending';
      if (currentStatus != 'Pending') {
        claimedByName = current['DispatcherName']?.toString();
        return Transaction.abort();
      }
      current['Status'] = newStatus;
      current['AcknowledgedAt'] = now;
      current['DispatcherId'] = dispatcherId;
      current['DispatcherName'] = dispatcherName;
      return Transaction.success(current);
    });

    if (!result.committed) {
      await slotRef.remove(); // free the slot — this dispatcher got nothing
      throw ReportAlreadyDispatchedException(claimedByName);
    }

    debugPrint(
      '✅ BFP Acknowledged: /$reportLabel/$reportId → $newStatus (by $dispatcherName)',
    );

    await _patchUserIndex(
      reportId: reportId,
      reportLabel: reportLabel,
      newStatus: newStatus,
    );
  }

  // ── Resolve ────────────────────────────────────────────────────────────────
  // Enforces the status lifecycle at the data layer (not just in the UI): a
  // report must already be Acknowledged (i.e. dispatched) before it can be
  // resolved. Reads the current status straight from the DB rather than
  // trusting the caller's possibly-stale copy, since multiple dispatchers
  // can be looking at the same report at once.
  Future<void> resolveReport(
    String reportId, {
    String reportLabel = 'fire-report',
  }) async {
    final report = await _fetchReport(reportId, reportLabel);
    final currentStatus = report?['Status']?.toString();
    if (currentStatus != 'Acknowledged') {
      throw StateError(
        'Report must be dispatched (Acknowledged) before it can be resolved '
        '(current status: ${currentStatus ?? 'unknown'}).',
      );
    }

    const newStatus = 'Resolved';

    await http
        .patch(
          Uri.parse('$_dbUrl$reportLabel/$reportId.json'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'Status': newStatus,
            'ResolvedAt': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('✅ BFP Resolved: /$reportLabel/$reportId → $newStatus');

    await _patchUserIndex(
      reportId: reportId,
      reportLabel: reportLabel,
      newStatus: newStatus,
    );

    // Free up the dispatcher's active-report slot so they can dispatch
    // another report.
    final dispatcherId = report?['DispatcherId']?.toString();
    if (dispatcherId != null && dispatcherId.isNotEmpty) {
      await _releaseDispatcherSlot(dispatcherId, reportId);
    }
  }

  // ── Read a report's full record straight from the DB ─────────────────────
  Future<Map<String, dynamic>?> _fetchReport(
    String reportId,
    String reportLabel,
  ) async {
    try {
      final resp = await http
          .get(Uri.parse('$_dbUrl$reportLabel/$reportId.json'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('BFP _fetchReport error: $e');
      return null;
    }
  }

  // ── Clear /BFPActiveReport/{dispatcherId} if it still points at this
  // report (only the report that's actually holding the slot may release
  // it) ──────────────────────────────────────────────────────────────────────
  Future<void> _releaseDispatcherSlot(
    String dispatcherId,
    String reportId,
  ) async {
    try {
      final ref = FirebaseDatabase.instance.ref(
        'BFPActiveReport/$dispatcherId',
      );
      final snap = await ref.get();
      final value = snap.value;
      if (value is Map && value['ReportId']?.toString() == reportId) {
        await ref.remove();
      }
    } catch (e) {
      debugPrint('BFP _releaseDispatcherSlot error (non-fatal): $e');
    }
  }

  // ── Patch user index ────────────────────────────────────────────────────────
  Future<void> _patchUserIndex({
    required String reportId,
    required String reportLabel,
    required String newStatus,
  }) async {
    try {
      final resp = await http
          .get(Uri.parse('$_dbUrl$reportLabel/$reportId.json'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return;
      final data = json.decode(resp.body);
      if (data == null || data is! Map) return;

      final userId = data['UserId']?.toString() ?? '';
      if (userId.isEmpty) return;

      await http
          .patch(
            Uri.parse('${_dbUrl}UserEmergencyReports/$userId/$reportId.json'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'Status': newStatus}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('BFP _patchUserIndex error (non-fatal): $e');
    }
  }

  // ── Group by barangay ──────────────────────────────────────────────────────
  Map<String, List<EmergencyReport>> groupByBarangay(
    List<EmergencyReport> reports, {
    bool includeResolved = false,
  }) {
    final filtered = includeResolved
        ? reports
        : reports.where((r) => r.status != 'Resolved').toList();

    final grouped = <String, List<EmergencyReport>>{};
    for (final r in filtered) {
      grouped.putIfAbsent(r.barangay, () => []).add(r);
    }
    return grouped;
  }
}

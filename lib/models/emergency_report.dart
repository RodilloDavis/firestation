import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class EmergencyReport {
  final String reportId;
  final String reportLabel;
  final String emergencyType;
  final String userName;
  final String userId;
  final String address;
  final String barangay;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> details;
  final String? dispatcherId;
  final String? dispatcherName;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  const EmergencyReport({
    required this.reportId,
    required this.reportLabel,
    required this.emergencyType,
    required this.userName,
    required this.userId,
    required this.address,
    required this.barangay,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    required this.details,
    this.dispatcherId,
    this.dispatcherName,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  factory EmergencyReport.fromMap(
    Map<dynamic, dynamic> map,
    String id, {
    String reportLabel = 'fire-report',
  }) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      final dt = DateTime.tryParse(v.toString());
      return dt ?? DateTime.now();
    }

    final location = map['Location'] as Map? ?? {};
    final barangay =
        map['Barangay']?.toString() ??
        map['barangay']?.toString() ??
        location['barangay']?.toString() ??
        'Unknown';

    final address =
        map['Address']?.toString() ??
        map['address']?.toString() ??
        location['address']?.toString() ??
        'No address provided';

    return EmergencyReport(
      reportId: id,
      reportLabel: reportLabel,
      emergencyType: 'fire',
      userName:
          map['UserName']?.toString() ??
          map['userName']?.toString() ??
          'Unknown',
      userId: map['UserId']?.toString() ?? map['userId']?.toString() ?? '',
      address: address,
      barangay: barangay,
      latitude: parseDouble(
        location['latitude'] ?? location['Latitude'] ?? map['Latitude'],
      ),
      longitude: parseDouble(
        location['longitude'] ?? location['Longitude'] ?? map['Longitude'],
      ),
      status: map['Status']?.toString() ?? 'Pending',
      createdAt: parseDate(map['CreatedAt'] ?? map['Timestamp']),
      details: Map<String, dynamic>.from(map),
      dispatcherId: map['DispatcherId']?.toString(),
      dispatcherName: map['DispatcherName']?.toString(),
      acknowledgedAt: DateTime.tryParse(
        map['AcknowledgedAt']?.toString() ?? '',
      ),
      resolvedAt: DateTime.tryParse(map['ResolvedAt']?.toString() ?? ''),
    );
  }

  // ── Response-time metrics ────────────────────────────────────────────────

  Duration? get timeToDispatch => acknowledgedAt?.difference(createdAt);

  Duration? get timeToResolve => (acknowledgedAt != null && resolvedAt != null)
      ? resolvedAt!.difference(acknowledgedAt!)
      : null;

  static String formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  Color get typeColor => AppColors.fire;
  String get typeIcon => '🔥';

  Color get statusColor {
    switch (status) {
      case 'Resolved':
        return AppColors.resolved;
      case 'Acknowledged':
        return AppColors.acknowledged;
      default:
        return AppColors.pending;
    }
  }

  String get fireType =>
      details['FireType']?.toString() ??
      details['fireType']?.toString() ??
      'Unknown';

  bool get peopleTrapped =>
      details['PeopleTrapped'] == true || details['peopleTrapped'] == true;

  int get numberOfPeople =>
      int.tryParse(
        (details['NumberOfPeople'] ?? details['numberOfPeople'] ?? '0')
            .toString(),
      ) ??
      0;

  bool get spreadingFast =>
      details['SpreadingFast'] == true || details['spreadingFast'] == true;

  String get additionalInfo =>
      details['AdditionalInfo']?.toString() ??
      details['additionalInfo']?.toString() ??
      '';
}

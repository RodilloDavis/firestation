import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/emergency_report.dart';
import '../services/auth_service.dart';
import '../services/dispatcher_service.dart';
import '../services/bfp_fcm_service.dart';
import '../widgets/barangay_group.dart';
import '../widgets/report_detail_panel.dart';
import '../widgets/map_panel.dart';
import 'login_screen.dart';
import 'profile_settings_screen.dart';

class DispatcherScreen extends StatefulWidget {
  const DispatcherScreen({super.key});

  @override
  State<DispatcherScreen> createState() => _DispatcherScreenState();
}

class _DispatcherScreenState extends State<DispatcherScreen> {
  final DispatcherService _service = DispatcherService();

  List<EmergencyReport> _reports = [];
  EmergencyReport? _selectedReport;

  // On wide layout: true = show detail panel, false = show map
  bool _showDetailOnWide = false;

  // On narrow map tab: show a floating mini card at bottom
  bool _showMapMiniCard = false;

  bool _isLoading = true;
  String? _dispatcherName;
  String? _dispatcherId;
  StreamSubscription? _streamSub;

  // Bottom nav: 0 = Reports, 1 = Map
  int _bottomNavIndex = 0;

  // Report filter tabs: 0 = All, 1 = Pending, 2 = Acknowledged, 3 = Resolved
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = await AuthService.getSession();
    if (session != null) {
      setState(() {
        _dispatcherName = session['fullName'];
        _dispatcherId = session['userId'];
      });
      await BfpFcmService.initialize(
        dispatcherId: session['userId'] ?? '',
        dispatcherName: session['fullName'] ?? 'BFP Dispatcher',
      );
    }

    _streamSub = _service.watchReports().listen((reports) {
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  List<EmergencyReport> get _filteredReports {
    switch (_tabIndex) {
      case 1:
        return _reports.where((r) => r.status == 'Pending').toList();
      case 2:
        return _reports.where((r) => r.status == 'Acknowledged').toList();
      case 3:
        return _reports.where((r) => r.status == 'Resolved').toList();
      default:
        return _reports;
    }
  }

  Map<String, List<EmergencyReport>> get _grouped => _service.groupByBarangay(
    _filteredReports,
    includeResolved: _tabIndex == 0 || _tabIndex == 3,
  );

  int get _pendingCount => _reports.where((r) => r.status == 'Pending').length;
  int get _ackCount => _reports.where((r) => r.status == 'Acknowledged').length;
  int get _resolvedCount =>
      _reports.where((r) => r.status == 'Resolved').length;

  Future<void> _openProfile() async {
    final session = await AuthService.getSession();
    if (session == null || !mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSettingsScreen(session: session),
      ),
    );
    if (result is Map<String, dynamic> && mounted) {
      setState(() {
        _dispatcherName = result['fullName']?.toString() ?? _dispatcherName;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_dispatcherId != null) {
        await BfpFcmService.removeToken(_dispatcherId!);
      }
      await AuthService.clearSession();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
      bottomNavigationBar: isWide ? null : _buildBottomNav(),
    );
  }

  // ── Wide layout ───────────────────────────────────────────────────────────
  // Left: report list (380px fixed)
  // Right: map OR detail panel — toggled by _showDetailOnWide

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left panel — always visible
        SizedBox(
          width: 380,
          child: Column(
            children: [
              _buildHeader(),
              _buildStats(),
              _buildTabs(),
              Expanded(child: _buildReportList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Right panel — map or detail, never a sheet covering the map
        Expanded(
          child: _showDetailOnWide && _selectedReport != null
              ? Column(
                  children: [
                    // Back to map bar
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showDetailOnWide = false),
                            icon: const Icon(
                              Icons.map_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Back to Map',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ReportDetailPanel(
                        report: _selectedReport!,
                        service: _service,
                        dispatcherId: _dispatcherId ?? '',
                        dispatcherName: _dispatcherName ?? 'BFP Dispatcher',
                        onStatusChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                )
              : BfpMapPanel(
                  reports: _reports,
                  selectedReport: _selectedReport,
                  dispatcherId: _dispatcherId ?? '',
                  onReportTap: (r) {
                    setState(() {
                      _selectedReport = r;
                      _showDetailOnWide = true;
                    });
                  },
                ),
        ),
      ],
    );
  }

  // ── Narrow layout ─────────────────────────────────────────────────────────
  // Bottom nav: Reports tab | Map tab
  // Map tab: full-screen map with a small dismissable card at the bottom
  // when a marker is tapped — does NOT cover the map

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _bottomNavIndex == 0
              // ── Reports tab ──────────────────────────────────────────
              ? Column(
                  children: [
                    _buildStats(),
                    _buildTabs(),
                    Expanded(child: _buildReportList()),
                  ],
                )
              // ── Map tab ──────────────────────────────────────────────
              : Stack(
                  children: [
                    // Full-screen map — always fully interactive
                    BfpMapPanel(
                      reports: _reports,
                      selectedReport: _selectedReport,
                      dispatcherId: _dispatcherId ?? '',
                      onReportTap: (r) {
                        setState(() {
                          _selectedReport = r;
                          _showMapMiniCard = true;
                        });
                      },
                    ),

                    // Mini card at bottom — only covers ~30% of screen
                    // Does NOT block map interaction above it
                    if (_showMapMiniCard && _selectedReport != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildMapMiniCard(_selectedReport!),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Mini card shown on map tab when marker is tapped ─────────────────────

  Widget _buildMapMiniCard(EmergencyReport report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + close
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.grey,
                  ),
                  onPressed: () => setState(() => _showMapMiniCard = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Fire type + status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.fireType.isNotEmpty
                        ? report.fireType
                        : 'Fire Emergency',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: report.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: report.statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    report.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: report.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Reporter + location
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 13,
                      color: AppColors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report.userName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.darkGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_city,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Brgy. ${report.barangay}, Panabo City',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (report.peopleTrapped)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          size: 13,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.numberOfPeople} person(s) trapped',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _showMapMiniCard = false);
                      _showFullDetail(report);
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (report.status == 'Pending') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _service.acknowledgeReport(
                            report.reportId,
                            reportLabel: report.reportLabel,
                            dispatcherId: _dispatcherId ?? '',
                            dispatcherName: _dispatcherName ?? 'BFP Dispatcher',
                          );
                          if (!mounted) return;
                          setState(() {
                            _showMapMiniCard = false;
                            _selectedReport = null;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to acknowledge: $e'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text('Acknowledge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.acknowledged,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ] else if (report.status == 'Acknowledged') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _service.resolveReport(
                            report.reportId,
                            reportLabel: report.reportLabel,
                          );
                          if (!mounted) return;
                          setState(() {
                            _showMapMiniCard = false;
                            _selectedReport = null;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to resolve: $e'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.task_alt, size: 14),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.resolved,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Full detail — pushed as a new screen (doesn't cover map) ─────────────

  void _showFullDetail(EmergencyReport r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text(
              'Fire Report Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ReportDetailPanel(
            report: r,
            service: _service,
            dispatcherId: _dispatcherId ?? '',
            dispatcherName: _dispatcherName ?? 'BFP Dispatcher',
            onStatusChanged: () => setState(() {}),
          ),
        ),
      ),
    );
  }

  // ── Bottom nav bar ────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EDF5))),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() {
          _bottomNavIndex = i;
          _showMapMiniCard = false;
        }),
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.list_alt_outlined),
                if (_pendingCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.pending,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Reports',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BFP FIRE DISPATCHER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_dispatcherName != null)
                  Text(
                    _dispatcherName!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline, color: Colors.white70, size: 20),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          _StatChip(
            label: 'Pending',
            count: _pendingCount,
            color: AppColors.pending,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Active',
            count: _ackCount,
            color: AppColors.acknowledged,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Resolved',
            count: _resolvedCount,
            color: AppColors.resolved,
          ),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Text(
              '${_reports.length} total',
              style: const TextStyle(fontSize: 11, color: AppColors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['All', 'Pending', 'Active', 'Resolved'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: List.generate(
          tabs.length,
          (i) => Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _tabIndex == i
                      ? AppColors.primary
                      : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _tabIndex == i ? Colors.white : AppColors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final grouped = _grouped;
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'No fire reports',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Incoming reports will appear here',
              style: TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: grouped.entries
          .map(
            (entry) => BarangayGroup(
              barangayName: entry.key,
              reports: entry.value,
              selectedReportId: _selectedReport?.reportId,
              onReportTap: (r) => setState(() => _selectedReport = r),
              onAcknowledge: (id, {reportLabel = 'fire-report'}) async {
                try {
                  await _service.acknowledgeReport(
                    id,
                    reportLabel: reportLabel,
                    dispatcherId: _dispatcherId ?? '',
                    dispatcherName: _dispatcherName ?? 'BFP Dispatcher',
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to acknowledge: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              onResolve: (id, {reportLabel = 'fire-report'}) async {
                try {
                  await _service.resolveReport(id, reportLabel: reportLabel);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to resolve: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              onViewReport: (r) {
                setState(() => _selectedReport = r);
                final isWide = MediaQuery.of(context).size.width >= 720;
                if (isWide) {
                  setState(() => _showDetailOnWide = true);
                } else {
                  _showFullDetail(r);
                }
              },
            ),
          )
          .toList(),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

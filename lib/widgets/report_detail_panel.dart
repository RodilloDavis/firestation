import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/emergency_report.dart';
import '../core/app_colors.dart';
import '../services/dispatcher_service.dart';

class ReportDetailPanel extends StatelessWidget {
  final EmergencyReport report;
  final DispatcherService service;
  final String dispatcherId;
  final String dispatcherName;
  final VoidCallback onStatusChanged;

  const ReportDetailPanel({
    super.key,
    required this.report,
    required this.service,
    required this.dispatcherId,
    required this.dispatcherName,
    required this.onStatusChanged,
  });

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _acknowledge(BuildContext context) async {
    try {
      await service.acknowledgeReport(
        report.reportId,
        reportLabel: report.reportLabel,
        dispatcherId: dispatcherId,
        dispatcherName: dispatcherName,
      );
      onStatusChanged();
    } on DispatcherHasActiveReportException catch (e) {
      if (context.mounted) _showError(context, e.toString());
    } on ReportAlreadyDispatchedException catch (e) {
      if (context.mounted) _showError(context, e.toString());
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to acknowledge: $e');
    }
  }

  Future<void> _resolve(BuildContext context) async {
    try {
      await service.resolveReport(
        report.reportId,
        reportLabel: report.reportLabel,
      );
      onStatusChanged();
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to resolve: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'FIRE EMERGENCY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      _StatusBadge(status: report.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Report ID: ${report.reportId}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location card
                  _SectionCard(
                    title: 'Location',
                    icon: Icons.location_on,
                    iconColor: AppColors.primary,
                    children: [
                      _DetailRow(
                        icon: Icons.location_city,
                        label: 'Barangay',
                        value: 'Brgy. ${report.barangay}, Panabo City',
                      ),
                      _DetailRow(
                        icon: Icons.place_outlined,
                        label: 'Address',
                        value: report.address,
                      ),
                      if (report.latitude != 0 && report.longitude != 0)
                        _DetailRow(
                          icon: Icons.gps_fixed,
                          label: 'Coordinates',
                          value:
                              '${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reporter card
                  _SectionCard(
                    title: 'Reporter',
                    icon: Icons.person,
                    iconColor: AppColors.primaryDark,
                    children: [
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: report.userName,
                      ),
                      _DetailRow(
                        icon: Icons.access_time,
                        label: 'Reported At',
                        value: DateFormat(
                          'MMM dd, yyyy – hh:mm a',
                        ).format(report.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fire details card
                  _SectionCard(
                    title: 'Fire Details',
                    icon: Icons.local_fire_department,
                    iconColor: AppColors.fire,
                    children: [
                      if (report.fireType.isNotEmpty &&
                          report.fireType != 'Unknown')
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Fire Type',
                          value: report.fireType,
                        ),
                      _DetailRow(
                        icon: Icons.people_outline,
                        label: 'People Trapped',
                        value: report.peopleTrapped
                            ? '⚠️ YES — ${report.numberOfPeople} person(s)'
                            : 'None reported',
                        valueColor: report.peopleTrapped
                            ? AppColors.danger
                            : null,
                      ),
                      _DetailRow(
                        icon: Icons.trending_up,
                        label: 'Spreading Fast',
                        value: report.spreadingFast ? '⚠️ YES' : 'No',
                        valueColor: report.spreadingFast
                            ? AppColors.warning
                            : null,
                      ),
                      if (report.additionalInfo.isNotEmpty)
                        _DetailRow(
                          icon: Icons.notes,
                          label: 'Additional Info',
                          value: report.additionalInfo,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  if (report.status == 'Pending') ...[
                    _ActionBtn(
                      label: 'Acknowledge Report',
                      icon: Icons.check_circle_outline,
                      color: AppColors.acknowledged,
                      onPressed: () => _acknowledge(context),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acknowledge this report first — Resolve unlocks once '
                      'it\'s dispatched.',
                      style: TextStyle(fontSize: 11, color: AppColors.grey),
                    ),
                  ] else if (report.status == 'Acknowledged') ...[
                    if (report.dispatcherName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Dispatched by ${report.dispatcherName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.acknowledged,
                          ),
                        ),
                      ),
                    _ActionBtn(
                      label: 'Mark as Resolved',
                      icon: Icons.task_alt,
                      color: AppColors.resolved,
                      onPressed: () => _resolve(context),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.resolved.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.resolved.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.resolved,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'This report has been resolved',
                            style: TextStyle(
                              color: AppColors.resolved,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'Resolved':
        return AppColors.resolved;
      case 'Acknowledged':
        return AppColors.acknowledged;
      default:
        return AppColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _color == AppColors.pending
              ? Colors.orange[100]
              : Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1A2035),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

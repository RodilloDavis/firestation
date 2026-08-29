import 'package:flutter/material.dart';
import '../models/emergency_report.dart';
import '../core/app_colors.dart';
import '../widgets/report_card.dart';

class BarangayGroup extends StatefulWidget {
  final String barangayName;
  final List<EmergencyReport> reports;
  final String? selectedReportId;
  final Function(EmergencyReport) onReportTap;
  final Function(String, {String reportLabel}) onAcknowledge;
  final Function(String, {String reportLabel}) onResolve;
  final Function(EmergencyReport) onViewReport;

  const BarangayGroup({
    super.key,
    required this.barangayName,
    required this.reports,
    required this.selectedReportId,
    required this.onReportTap,
    required this.onAcknowledge,
    required this.onResolve,
    required this.onViewReport,
  });

  @override
  State<BarangayGroup> createState() => _BarangayGroupState();
}

class _BarangayGroupState extends State<BarangayGroup>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded ? _controller.forward() : _controller.reverse();
    });
  }

  int get _pendingCount =>
      widget.reports.where((r) => r.status == 'Pending').length;
  int get _acknowledgedCount =>
      widget.reports.where((r) => r.status == 'Acknowledged').length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggle,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.barangayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A2035),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.reports.length} report${widget.reports.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pendingCount > 0) ...[
                  _CountPill(
                    count: _pendingCount,
                    color: AppColors.pending,
                    label: 'P',
                  ),
                  const SizedBox(width: 4),
                ],
                if (_acknowledgedCount > 0) ...[
                  _CountPill(
                    count: _acknowledgedCount,
                    color: AppColors.acknowledged,
                    label: 'A',
                  ),
                  const SizedBox(width: 4),
                ],
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Column(
            children: widget.reports
                .map(
                  (r) => ReportCard(
                    report: r,
                    isSelected: widget.selectedReportId == r.reportId,
                    onTap: () => widget.onReportTap(r),
                    onAcknowledge: () => widget.onAcknowledge(
                      r.reportId,
                      reportLabel: r.reportLabel,
                    ),
                    onResolve: () => widget.onResolve(
                      r.reportId,
                      reportLabel: r.reportLabel,
                    ),
                    onViewReport: () => widget.onViewReport(r),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _CountPill({
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

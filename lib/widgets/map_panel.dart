import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_report.dart';
import '../core/app_colors.dart';
  
// ─── Panabo City center ───────────────────────────────────────────────────────
const _kPanaboCityCenter = LatLng(7.330964, 125.578847);

// ─── Known Panabo City barangays ─────────────────────────────────────────────
const Map<String, LatLng> kPanaboBarangays = {
  'Buenavista': LatLng(7.3125, 125.6780),
  'Cacao': LatLng(7.2950, 125.6920),
  'Cagangohan': LatLng(7.3200, 125.6950),
  'Consolacion': LatLng(7.3050, 125.6830),
  'Dapco': LatLng(7.3300, 125.7000),
  'Datu Abdul Dadia': LatLng(7.2900, 125.6700),
  'Gredu': LatLng(7.3090, 125.6760),
  'J.P. Laurel': LatLng(7.3060, 125.6880),
  'Kasilak': LatLng(7.3170, 125.6820),
  'Katipunan': LatLng(7.3010, 125.6950),
  'Kauswagan': LatLng(7.2980, 125.6800),
  'Kiotoy': LatLng(7.3250, 125.7050),
  'Little Panay': LatLng(7.3080, 125.6700),
  'Lower Panaga': LatLng(7.3150, 125.6620),
  'Mabunao': LatLng(7.3000, 125.6680),
  'Maduao': LatLng(7.2880, 125.6760),
  'Malativas': LatLng(7.2960, 125.7000),
  'Manay': LatLng(7.3350, 125.6900),
  'Nanyo': LatLng(7.3020, 125.7050),
  'New Malaga': LatLng(7.3100, 125.7100),
  'New Malitbog': LatLng(7.2930, 125.6850),
  'New Pandan': LatLng(7.3220, 125.6730),
  'New Visayas': LatLng(7.3080, 125.6990),
  'Panabo': LatLng(7.3090, 125.6840),
  'San Francisco': LatLng(7.3140, 125.6780),
  'San Nicolas': LatLng(7.3060, 125.6810),
  'Panacan': LatLng(7.2870, 125.6820),
  'Salvacion': LatLng(7.3180, 125.6890),
  'Santo Niño': LatLng(7.3050, 125.6760),
  'Sindaton': LatLng(7.2940, 125.6930),
  'Southern Davao': LatLng(7.3000, 125.6750),
  'Tagpore': LatLng(7.3260, 125.6810),
  'Tibungol': LatLng(7.3090, 125.6710),
  'Upper Licanan': LatLng(7.3190, 125.6960),
  'Waterfall': LatLng(7.3110, 125.6850),
};

// ─── BFP Map Panel ────────────────────────────────────────────────────────────
// Shows this dispatcher's single active (Acknowledged) fire report exclusively
// while they have one — nothing else competes for attention on the map. Once
// it's Resolved, the map automatically falls back to showing all Pending
// reports so the next dispatch can be picked.
class BfpMapPanel extends StatefulWidget {
  final List<EmergencyReport> reports;
  final EmergencyReport? selectedReport;
  final String dispatcherId;
  final Function(EmergencyReport) onReportTap;

  const BfpMapPanel({
    super.key,
    required this.reports,
    required this.selectedReport,
    required this.dispatcherId,
    required this.onReportTap,
  });

  @override
  State<BfpMapPanel> createState() => _BfpMapPanelState();
}

class _BfpMapPanelState extends State<BfpMapPanel> {
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  LatLng? _myLocation;
  bool _showLegend = false;
  bool _isLocating = false;

  static const _kDefaultZoom = 12.5;

  @override
  void initState() {
    super.initState();
    _buildMarkers();
  }

  @override
  void didUpdateWidget(BfpMapPanel old) {
    super.didUpdateWidget(old);
    if (old.reports != widget.reports ||
        old.selectedReport != widget.selectedReport) {
      _buildMarkers();
    }
  }

  // ── This dispatcher's own active dispatch, if any ─────────────────────────
  EmergencyReport? get _myActiveReport {
    for (final r in widget.reports) {
      if (r.status == 'Acknowledged' && r.dispatcherId == widget.dispatcherId) {
        return r;
      }
    }
    return null;
  }

  // ── What the map shows: exclusively my active report while I have one,
  // otherwise the full pending queue ────────────────────────────────────────
  List<EmergencyReport> get _visibleReports {
    final myActive = _myActiveReport;
    if (myActive != null) return [myActive];
    return widget.reports.where((r) => r.status == 'Pending').toList();
  }

  // ── Build map markers ───────────────────────────────────────────────────────
  void _buildMarkers() {
    final markers = <Marker>{};

    for (final report in _visibleReports) {
      if (report.latitude == 0 && report.longitude == 0) continue;

      final isSelected = widget.selectedReport?.reportId == report.reportId;
      final color = _markerHue(report);

      markers.add(
        Marker(
          markerId: MarkerId(report.reportId),
          position: LatLng(report.latitude, report.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(color),
          zIndex: isSelected ? 2 : 1,
          infoWindow: InfoWindow(
            title:
                '🔥 ${report.fireType.isNotEmpty ? report.fireType : 'Fire'} — Brgy. ${report.barangay}',
            snippet:
                '${report.userName} · ${report.status}${report.peopleTrapped ? ' · ⚠️ ${report.numberOfPeople} trapped' : ''}',
          ),
          onTap: () => widget.onReportTap(report),
        ),
      );
    }

    // Dispatcher's own location
    if (_myLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('_my_location'),
          position: _myLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          zIndex: 3,
          infoWindow: const InfoWindow(title: '🚒 BFP Dispatcher'),
        ),
      );
    }

    if (mounted) setState(() => _markers = markers);
  }

  double _markerHue(EmergencyReport report) {
    // All fire reports — colour by status
    switch (report.status) {
      case 'Acknowledged':
        return BitmapDescriptor.hueOrange;
      case 'Resolved':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed; // Pending = bright red
    }
  }

  // ── Get device location ─────────────────────────────────────────────────────
  Future<void> _locateMe() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _buildMarkers();

      final ctrl = await _mapController.future;
      ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    } catch (e) {
      debugPrint('BFP locateMe error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ── Fly to selected report ──────────────────────────────────────────────────
  Future<void> _flyToReport(EmergencyReport report) async {
    if (report.latitude == 0 && report.longitude == 0) return;
    final ctrl = await _mapController.future;
    ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(report.latitude, report.longitude), 16),
    );
  }

  // ── Reset to city center ────────────────────────────────────────────────────
  Future<void> _resetCamera() async {
    final ctrl = await _mapController.future;
    ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(_kPanaboCityCenter, _kDefaultZoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-fly when a report is selected externally
    if (widget.selectedReport != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flyToReport(widget.selectedReport!);
      });
    }

    return Stack(
      children: [
        // ── Google Map ────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _kPanaboCityCenter,
            zoom: _kDefaultZoom,
          ),
          markers: _markers,
          polygons: _polygons,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          onMapCreated: (ctrl) => _mapController.complete(ctrl),
        ),

        // Top bar — status banner reflects the map's automatic mode; only the
        // chip captures touches, the gap passes through to the map beneath.
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapStatusBanner(activeReport: _myActiveReport),
              if (widget.selectedReport != null) ...[
                const SizedBox(height: 8),
                _SelectedReportChip(report: widget.selectedReport!),
              ],
            ],
          ),
        ),

        // Right-side buttons — Column is min-sized, no invisible blocking area
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: Icons.my_location,
                onTap: _locateMe,
                loading: _isLocating,
              ),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.center_focus_strong, onTap: _resetCamera),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.layers_outlined,
                onTap: () => setState(() => _showLegend = !_showLegend),
              ),
            ],
          ),
        ),

        // Legend — GestureDetector absorbs all touches so map doesn't move
        if (_showLegend)
          Positioned(
            right: 56,
            bottom: 100,
            child: GestureDetector(
              onTap: () {},
              onScaleStart: (_) {},
              onScaleUpdate: (_) {},
              behavior: HitTestBehavior.opaque,
              child: _MapLegend(),
            ),
          ),

        // Stats bar — intrinsic size, map is still tappable above it
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _StatsBar(reports: widget.reports),
        ),
      ],
    );
  }
}

// ─── Mode chip ────────────────────────────────────────────────────────────────
class _MapStatusBanner extends StatelessWidget {
  final EmergencyReport? activeReport;
  const _MapStatusBanner({required this.activeReport});

  @override
  Widget build(BuildContext context) {
    final report = activeReport;
    final color = report != null ? AppColors.acknowledged : AppColors.primary;
    final icon = report != null
        ? Icons.local_shipping_outlined
        : Icons.local_fire_department;
    final label = report != null
        ? 'Active dispatch — Brgy. ${report.barangay}'
        : 'Showing pending reports';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Selected report chip ─────────────────────────────────────────────────────
class _SelectedReportChip extends StatelessWidget {
  final EmergencyReport report;
  const _SelectedReportChip({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${report.fireType.isNotEmpty ? report.fireType : 'Fire'} · Brgy. ${report.barangay}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              report.status,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map button ───────────────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
          ],
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(icon, size: 16, color: AppColors.darkGrey),
      ),
    );
  }
}

// ─── Map legend ───────────────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 8),
        ],
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendSection(label: 'MARKER STATUS'),
          SizedBox(height: 4),
          _LegendItem(color: AppColors.danger, label: 'Pending'),
          _LegendItem(color: AppColors.warning, label: 'Acknowledged'),
          _LegendItem(color: AppColors.success, label: 'Resolved'),
          SizedBox(height: 6),
          _LegendSection(label: 'UNIT'),
          SizedBox(height: 4),
          _LegendItem(
            color: AppColors.acknowledged,
            label: '🚒 BFP Dispatcher',
          ),
        ],
      ),
    );
  }
}

class _LegendSection extends StatelessWidget {
  final String label;
  const _LegendSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: AppColors.grey,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.darkGrey),
          ),
        ],
      ),
    );
  }
}

// ─── Stats bar ────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final List<EmergencyReport> reports;
  const _StatsBar({required this.reports});

  @override
  Widget build(BuildContext context) {
    final pending = reports.where((r) => r.status == 'Pending').length;
    final active = reports.where((r) => r.status == 'Acknowledged').length;
    final resolved = reports.where((r) => r.status == 'Resolved').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            label: 'Pending',
            count: pending,
            color: AppColors.pending,
            icon: Icons.local_fire_department,
          ),
          _VertDivider(),
          _StatItem(
            label: 'Active',
            count: active,
            color: AppColors.acknowledged,
            icon: Icons.directions_run,
          ),
          _VertDivider(),
          _StatItem(
            label: 'Resolved',
            count: resolved,
            color: AppColors.success,
            icon: Icons.task_alt,
          ),
          _VertDivider(),
          _StatItem(
            label: 'Total',
            count: reports.length,
            color: AppColors.darkGrey,
            icon: Icons.bar_chart,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.grey,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFFE8EDF5),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

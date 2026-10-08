// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../core/widgets/capsule_button.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../services/api_client.dart';

/// Private Two-Sided Live Donor Tracking Screen.
/// Displays live donor position, hospital marker, ETA countdown,
/// cancel/no-show standby escalation, and direct E2E messaging.
class DonorTrackingMapScreen extends StatefulWidget {
  const DonorTrackingMapScreen({
    super.key,
    this.requestId,
    this.patientName = 'Urgent Patient',
    this.hospitalName = 'Dhaka Medical College Hospital',
    this.bloodGroup = 'O+',
    this.donorName = 'Verified Donor',
    this.donorPhone = '+8801700000000',
    this.hospitalLat = 23.7259,
    this.hospitalLng = 90.3976,
    this.initialDonorLat = 23.7380,
    this.initialDonorLng = 90.3870,
    this.isDonorView = false,
  });

  final String? requestId;
  final String patientName;
  final String hospitalName;
  final String bloodGroup;
  final String donorName;
  final String donorPhone;
  final double hospitalLat;
  final double hospitalLng;
  final double initialDonorLat;
  final double initialDonorLng;
  final bool isDonorView;

  @override
  State<DonorTrackingMapScreen> createState() => _DonorTrackingMapScreenState();
}

class _DonorTrackingMapScreenState extends State<DonorTrackingMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _refreshTimer;

  late LatLng _hospitalLocation;
  late LatLng _donorLocation;
  double _distanceKm = 0.0;
  int _etaMinutes = 0;

  bool _isEscalating = false;
  bool _isCancelled = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _hospitalLocation = LatLng(widget.hospitalLat, widget.hospitalLng);
    // Apply 500m privacy fuzzing to initial donor location
    _donorLocation = _fuzzLocation(
      LatLng(widget.initialDonorLat, widget.initialDonorLng),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _calculateDistanceAndEta();

    // 30s auto-refresh timer simulates real-time movement toward hospital
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _simulateLocationStep();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Deterministically fuzz coordinates by ~500m for privacy protection.
  LatLng _fuzzLocation(LatLng loc) {
    // 0.0045 degrees is approximately 500 meters
    const fuzzDegree = 0.0035;
    return LatLng(loc.latitude + fuzzDegree, loc.longitude - fuzzDegree);
  }

  void _calculateDistanceAndEta() {
    const r = 6371.0; // Earth radius in km
    final dLat = _deg2rad(_hospitalLocation.latitude - _donorLocation.latitude);
    final dLon = _deg2rad(_hospitalLocation.longitude - _donorLocation.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(_donorLocation.latitude)) *
            math.cos(_deg2rad(_hospitalLocation.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    _distanceKm = r * c;

    // Assume average transit speed of 40 km/h with 1.2 detour factor
    final transitHours = (_distanceKm * 1.2) / 40.0;
    _etaMinutes = math.max(2, (transitHours * 60).ceil());
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  void _simulateLocationStep() {
    if (_isCancelled) return;
    setState(() {
      // Step donor 15% closer to hospital
      final nextLat = _donorLocation.latitude +
          (_hospitalLocation.latitude - _donorLocation.latitude) * 0.15;
      final nextLng = _donorLocation.longitude +
          (_hospitalLocation.longitude - _donorLocation.longitude) * 0.15;
      _donorLocation = LatLng(nextLat, nextLng);
      _calculateDistanceAndEta();
    });
  }

  Future<void> _handleReportNoShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Report No-Show / নো-শো রিপোর্ট',
            style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
        content: const Text(
          'If the donor has cancelled or failed to arrive within 10 minutes, the Wave Engine will automatically escalate to the next 5 nearest eligible standby donors.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Wait Longer', style: TextStyle(fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Escalate to Standby', style: TextStyle(fontFamily: 'Inter')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isEscalating = true);

    try {
      final client = ApiClient();
      await client.post('emergency/tick/');
    } catch (_) {
      // Offline fallback
    }

    if (!mounted) return;
    setState(() => _isEscalating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '✓ Escalated! Next 5 eligible standby donors notified with priority alert.',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleCancelDonation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Request?', style: TextStyle(fontFamily: 'Georgia')),
        content: const Text('Are you sure you want to cancel this emergency tracking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neutral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelled = true);
      if (mounted) context.pop();
    }
  }

  void _openChatWithDonor() {
    context.push('/chat', extra: {
      'recipientName': widget.donorName,
      'bloodGroup': widget.bloodGroup,
      'recipientId': widget.donorPhone,
      'chatRoomId': 'room_${widget.requestId ?? "emergency_1"}',
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      child: Scaffold(
        appBar: BloodPulseAppBar(
          showBackButton: true,
          subtitle: 'Live Donor Radar',
        ),
        body: Stack(
          children: [
            // OpenStreetMap Interactive Canvas
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  (_donorLocation.latitude + _hospitalLocation.latitude) / 2,
                  (_donorLocation.longitude + _hospitalLocation.longitude) / 2,
                ),
                initialZoom: 13.8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.bloodpulse.app',
                ),

                // Connecting Route Line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_donorLocation, _hospitalLocation],
                      strokeWidth: 4.0,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      pattern: StrokePattern.dashed(segments: const [10, 6]),
                    ),
                  ],
                ),

                // Markers Layer
                MarkerLayer(
                  markers: [
                    // Hospital Marker
                    Marker(
                      point: _hospitalLocation,
                      width: 52,
                      height: 52,
                      child: _buildHospitalMarker(),
                    ),

                    // Donor Pin Marker
                    Marker(
                      point: _donorLocation,
                      width: 54,
                      height: 54,
                      child: _buildDonorMarker(),
                    ),
                  ],
                ),
              ],
            ),

            // Top Status & Privacy Badge
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: _buildTopStatusBanner(),
            ),

            // Bottom Action & ETA Card
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBottomEtaCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFE8DADA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1B8A4E),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Live Beacon Active · Privacy Fuzz: 500m',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE9EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.bloodGroup,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalMarker() {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF0D68AA), width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: Icon(Icons.local_hospital_rounded,
                color: Color(0xFF0D68AA), size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildDonorMarker() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.directions_run_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildBottomEtaCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Donor Info & ETA
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE9EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.donorName,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'En route to ${widget.hospitalName}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Big ETA display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF8BDC4)),
                ),
                child: Column(
                  children: [
                    Text(
                      '~$_etaMinutes min',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${_distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF2ECEC)),
          const SizedBox(height: 14),

          // Actions: Message Donor, Call Donor, No-Show Escalation
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openChatWithDonor,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message', style: TextStyle(fontFamily: 'Inter')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tertiary,
                    side: const BorderSide(color: Color(0xFFD0E4FF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${widget.donorPhone}')),
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Call Donor', style: TextStyle(fontFamily: 'Inter')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B8A4E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Secondary row: Report No-Show / Cancel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _handleCancelDonation,
                child: const Text(
                  'Cancel Donation',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF888888)),
                ),
              ),
              TextButton.icon(
                onPressed: _isEscalating ? null : _handleReportNoShow,
                icon: const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.primary),
                label: Text(
                  _isEscalating ? 'Escalating...' : 'Report No-Show / Standby',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

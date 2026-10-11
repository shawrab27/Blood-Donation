// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/capsule_button.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../services/tracking_service.dart';
import '../data/blood_hub_v2_api_service.dart';
import 'widgets/report_broker_dialog.dart';
import 'widgets/request_units_progress_card.dart';
import 'widgets/tracking/donor_tracking_actions_sheet.dart';
import 'widgets/tracking/donor_tracking_bottom_panel.dart';

/// Private Two-Sided Live Donor Tracking Screen using real GPS via [TrackingService].
class DonorTrackingMapScreen extends ConsumerStatefulWidget {
  const DonorTrackingMapScreen({
    super.key,
    this.requestId,
    this.matchId,
    this.patientName = 'Urgent Patient',
    this.hospitalName = 'Dhaka Medical College Hospital',
    this.bloodGroup = 'O+',
    this.donorName = 'Verified Donor',
    this.donorPhone = '',
    this.hospitalLat = 23.7259,
    this.hospitalLng = 90.3976,
    this.initialDonorLat = 23.7380,
    this.initialDonorLng = 90.3870,
    this.isDonorView = false,
    this.chatRoomId = 'emergency_chat',
    this.unitsNeeded = 2,
    this.unitsReceived = 0,
    this.unitsPending = 1,
    this.requestMode = 'PROXY',
    this.supportStatus = 'CAN_SUPPORT',
  });

  final String? requestId;
  final dynamic matchId;
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
  final String chatRoomId;
  final int unitsNeeded;
  final int unitsReceived;
  final int unitsPending;
  final String requestMode;
  final String supportStatus;

  @override
  ConsumerState<DonorTrackingMapScreen> createState() => _DonorTrackingMapScreenState();
}

class _DonorTrackingMapScreenState extends ConsumerState<DonorTrackingMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription? _trackingSubscription;

  late LatLng _hospitalLocation;
  late LatLng _donorLocation;
  double _distanceKm = 0.0;
  int _etaMinutes = 0;
  String _currentStatus = 'IN_TRANSIT';
  bool _permissionDenied = false;

  int get _numericMatchId => int.tryParse(widget.matchId?.toString() ?? '') ?? 1;
  String get _trackingDocId => widget.matchId?.toString() ?? 'match_1';

  @override
  void initState() {
    super.initState();
    _hospitalLocation = LatLng(widget.hospitalLat, widget.hospitalLng);
    _donorLocation = LatLng(widget.initialDonorLat, widget.initialDonorLng);
    _calculateInitialDistanceAndEta();
    _initLiveTracking();
  }

  Future<void> _initLiveTracking() async {
    if (widget.isDonorView) {
      final perm = await TrackingService.instance.checkAndRequestPermission();
      if (!TrackingService.instance.isPermissionGranted(perm)) {
        if (mounted) setState(() => _permissionDenied = true);
      } else {
        if (mounted) setState(() => _permissionDenied = false);
        await TrackingService.instance.startDonorTracking(
          matchId: _trackingDocId,
          donorUid: 'donor_${widget.donorName}',
          requesterUid: 'requester_${widget.patientName}',
          hospitalLat: widget.hospitalLat,
          hospitalLng: widget.hospitalLng,
        );
      }
    }

    _trackingSubscription = TrackingService.instance
        .streamTracking(_trackingDocId)
        ?.listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final loc = data['donorLocation'] as Map<String, dynamic>?;
      if (loc != null) {
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() {
            _donorLocation = LatLng(lat, lng);
            _distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? _distanceKm;
            _etaMinutes = (data['etaMinutes'] as num?)?.toInt() ?? _etaMinutes;
            _currentStatus = (data['status'] as String?) ?? _currentStatus;
          });
        }
      }
    });
  }

  void _calculateInitialDistanceAndEta() {
    const r = 6371.0;
    final dLat = (math.pi / 180.0) * (_hospitalLocation.latitude - _donorLocation.latitude);
    final dLon = (math.pi / 180.0) * (_hospitalLocation.longitude - _donorLocation.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos((math.pi / 180.0) * _donorLocation.latitude) *
            math.cos((math.pi / 180.0) * _hospitalLocation.latitude) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    _distanceKm = double.parse((r * c).toStringAsFixed(1));
    final transitHours = (_distanceKm * 1.2) / 40.0;
    _etaMinutes = math.max(2, (transitHours * 60).ceil());
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    if (widget.isDonorView) {
      TrackingService.instance.stopTracking();
    }
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    try {
      await ref.read(bloodHubV2ApiServiceProvider).updateMatchStatus(_numericMatchId, status);
      if (!mounted) return;
      setState(() => _currentStatus = status);
      if (status == 'ARRIVED' && widget.isDonorView) {
        await TrackingService.instance.stopTracking();
      } else if (status == 'DONATED') {
        await TrackingService.instance.closeAndCleanup(_trackingDocId);
        if (mounted) {
          context.push('/blood-hub/thanks', extra: {
            'matchId': _numericMatchId,
            'donorName': widget.donorName,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2B2B2B)),
            onPressed: () => context.canPop() ? context.pop() : context.go('/blood-hub'),
          ),
          title: Text(
            widget.isDonorView ? 'En Route to Hospital' : 'Live Donor Dispatch',
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
          ),
          actions: [
            IconButton(
              tooltip: 'Report Broker / Issue',
              icon: const Icon(Icons.flag_outlined, color: Color(0xFFC30121)),
              onPressed: () => ReportBrokerDialog.show(
                context,
                requestId: int.tryParse(widget.requestId ?? ''),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _donorLocation,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.bloodpulse.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_donorLocation, _hospitalLocation],
                      strokeWidth: 4.0,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _hospitalLocation,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 36),
                    ),
                    Marker(
                      point: _donorLocation,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.navigation_rounded, color: AppColors.tertiary, size: 36),
                    ),
                  ],
                ),
              ],
            ),
            if (_permissionDenied)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded, color: Color(0xFF856404)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Location permission required for live transit GPS.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF856404)),
                        ),
                      ),
                      TextButton(onPressed: _initLiveTracking, child: const Text('Allow')),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RequestUnitsProgressCard(
                    compact: true,
                    unitsReceived: _currentStatus == 'DONATED'
                        ? widget.unitsNeeded
                        : widget.unitsReceived,
                    unitsPending: _currentStatus == 'DONATED'
                        ? 0
                        : widget.unitsPending,
                    unitsNeeded: widget.unitsNeeded,
                    requestMode: widget.requestMode,
                    supportStatus: widget.supportStatus,
                  ),
                  const SizedBox(height: 10),
                  DonorTrackingBottomPanel(
                    distanceKm: _distanceKm,
                    etaMinutes: _etaMinutes,
                    currentStatus: _currentStatus,
                    isDonorView: widget.isDonorView,
                    patientName: widget.patientName,
                    donorName: widget.donorName,
                    chatRoomId: widget.chatRoomId,
                    numericMatchId: _numericMatchId,
                    onStatusUpdate: _updateStatus,
                    onReportSuccess: () => setState(() => _currentStatus = 'FAILED'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

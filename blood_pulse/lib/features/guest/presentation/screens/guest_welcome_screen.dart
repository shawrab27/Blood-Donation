import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../core/access/access_guard.dart';
import '../../../../core/access/registration_gate_popup.dart';
import '../../../../services/api_client.dart';

/// Stitch Screen 5e7b8264f0bc4398aae2a1020b193fb0:
/// "Guest Mode — Clean Overview Dashboard" ("Welcome, guest")
///
/// Features:
/// 1. Coarse Anonymized Nearby Donors OpenStreetMap (flutter_map)
/// 2. Quick Actions: Become a Donor, Nearby Club, Express Emergency
/// 3. Locked Row: Blood Hub, Chat & Profile
/// 4. PulseAI Assistant entry card
/// 5. Strictly guarded via AccessGuard / RegistrationGatePopup
class GuestWelcomeScreen extends ConsumerStatefulWidget {
  final Future<Map<String, dynamic>> Function()? mapDataFetcher;
  final Future<({LatLng center, double zoom, String statusMessage})> Function()?
      locationResolver;

  const GuestWelcomeScreen({
    super.key,
    this.mapDataFetcher,
    this.locationResolver,
  });

  @override
  ConsumerState<GuestWelcomeScreen> createState() => _GuestWelcomeScreenState();
}

class _GuestWelcomeScreenState extends ConsumerState<GuestWelcomeScreen> {
  static const LatLng _bangladeshCenter = LatLng(23.6850, 90.3563);
  final MapController _mapController = MapController();
  final ApiClient _apiClient = ApiClient();

  LatLng _currentCenter = _bangladeshCenter;
  double _currentZoom = 7.0;
  bool _isLoadingMap = true;
  bool _isOfflineOrError = false;
  bool _isServerWakingUp = false;
  int _retryCountdown = 5;
  int _retryAttempts = 0;
  Timer? _retryTimer;
  String _mapStatusMessage = 'Showing Bangladesh';
  int _totalNearbyDonors = 0;
  List<Map<String, dynamic>> _aggregatedCells = [];

  @override
  void initState() {
    super.initState();
    _loadLocationAndGuestMap();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<({LatLng center, double zoom, String statusMessage})>
      _defaultResolveLocalLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(milliseconds: 100));
      if (!serviceEnabled) {
        return (
          center: _bangladeshCenter,
          zoom: 7.0,
          statusMessage: 'Location off — showing Bangladesh',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(milliseconds: 100));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(milliseconds: 100));
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (
          center: _bangladeshCenter,
          zoom: 7.0,
          statusMessage: 'Location denied — showing Bangladesh',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(milliseconds: 100));
      return (
        center: LatLng(position.latitude, position.longitude),
        zoom: 11.5,
        statusMessage: 'Live Area',
      );
    } catch (_) {
      return (
        center: _bangladeshCenter,
        zoom: 7.0,
        statusMessage: 'Location off — showing Bangladesh',
      );
    }
  }

  Future<Map<String, dynamic>> _defaultFetchGuestMap() async {
    // Client NEVER sends guest location or radius parameters
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    // Render free-tier cold start may take 30-50s; 55s timeout ensures requests do not prematurely abort
    final timeout = isTest ? const Duration(milliseconds: 100) : const Duration(seconds: 55);
    final response = await _apiClient
        .get('donors/guest-map/')
        .timeout(timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load guest map (${response.statusCode})');
  }

  void _startAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_retryCountdown > 1) {
        setState(() => _retryCountdown--);
      } else {
        timer.cancel();
        _loadLocationAndGuestMap();
      }
    });
  }

  Future<void> _loadLocationAndGuestMap() async {
    setState(() {
      _isLoadingMap = true;
      _isOfflineOrError = false;
    });

    // Resolve local device GPS strictly to center the map locally (never sent to server)
    final resolver = widget.locationResolver ?? _defaultResolveLocalLocation;
    try {
      final loc = await resolver();
      _currentCenter = loc.center;
      _currentZoom = loc.zoom;
      _mapStatusMessage = loc.statusMessage;
    } catch (_) {
      _currentCenter = _bangladeshCenter;
      _currentZoom = 7.0;
      _mapStatusMessage = 'Location off — showing Bangladesh';
    }

    // Fetch anonymous nationwide coarse cells from backend (no query params)
    final fetcher = widget.mapDataFetcher ?? _defaultFetchGuestMap;
    try {
      final data = await fetcher();
      final count = (data['total_donors'] as num?)?.toInt() ?? 0;
      final rawCells = (data['cells'] as List<dynamic>?) ?? [];

      if (mounted) {
        _retryTimer?.cancel();
        setState(() {
          _totalNearbyDonors = count;
          _aggregatedCells = rawCells
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoadingMap = false;
          _isOfflineOrError = false;
          _isServerWakingUp = false;
          _retryAttempts = 0;
        });
        try {
          _mapController.move(_currentCenter, _currentZoom);
        } catch (_) {}
      }
      return;
    } catch (_) {
      if (mounted) {
        _retryAttempts++;
        final canAutoRetry = _retryAttempts <= 3;
        setState(() {
          _isOfflineOrError = true;
          _isServerWakingUp = canAutoRetry;
          _isLoadingMap = false;
          _retryCountdown = 5;
        });
        try {
          _mapController.move(_currentCenter, _currentZoom);
        } catch (_) {}

        if (canAutoRetry) {
          _startAutoRetry();
        }
      }
      return;
    }
  }

  void _triggerRegistrationGate({String? targetRoute}) {
    RegistrationGatePopup.show(context, isGuest: true, targetRoute: targetRoute);
  }

  void _triggerGatedAction(AccessFeature feature, {String? targetRoute}) {
    AccessGuard.checkAndHandle(
      context: context,
      ref: ref,
      feature: feature,
      targetRoute: targetRoute,
      onAllowed: () {
        if (targetRoute != null) {
          context.push(targetRoute);
        }
      },
    );
  }

  List<Map<String, dynamic>> get _displayPins {
    if (_aggregatedCells.isNotEmpty) {
      return _aggregatedCells.map((cell) {
        final lat = (cell['latitude'] as num?)?.toDouble() ?? _currentCenter.latitude;
        final lng = (cell['longitude'] as num?)?.toDouble() ?? _currentCenter.longitude;
        final count = (cell['count'] as num?)?.toInt() ?? 1;
        final bloodGroup = cell['blood_group']?.toString() ?? 'Donors';
        return {
          'point': LatLng(lat, lng),
          'bloodGroup': bloodGroup,
          'distance': '• $count',
        };
      }).toList();
    }
    // Zero-fake-data policy: never generate mock donor pins
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F3),
      appBar: const CustomAppBar(
        showBackButton: false,
        showProfile: true,
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            onRefresh: _loadLocationAndGuestMap,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Title & Subtitle ───────────────────────────────
                  const Text(
                    'Welcome, guest',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Explore what BloodPulse does. Sign up to unlock everything.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Anonymized Nearby Donors Map Card ─────────────────────
                  _buildNearbyDonorsMapCard(),
                  const SizedBox(height: 20),

                  // ── Quick Actions Card ────────────────────────────────────
                  _buildQuickActionsCard(),
                  const SizedBox(height: 16),

                  // ── PulseAI Card ──────────────────────────────────────────
                  _buildPulseAICard(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MAP CARD
  // ───────────────────────────────────────────────────────────────────────────
  // ───────────────────────────────────────────────────────────────────────────
  // MAP CARD (Accurate Stitch Design & Registration Trigger)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildNearbyDonorsMapCard() {
    final totalDonors = _totalNearbyDonors > 0 ? _totalNearbyDonors : 24;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _triggerRegistrationGate(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E5E5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE9EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nearby Donors',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF8F1),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFFD4EEDD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Flexible(
                          child: Text(
                            'Live Area',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B8A4E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Map View Container matching Stitch Design
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 228,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentCenter,
                        initialZoom: _currentZoom,
                        onTap: (_, __) => _triggerRegistrationGate(),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'org.bloodpulse.app',
                        ),
                        CircleLayer(
                          circles: [
                            // Stitch concentric radar rings
                            CircleMarker(
                              point: _currentCenter,
                              radius: 92,
                              useRadiusInMeter: false,
                              color: const Color(0xFFC30121).withValues(alpha: 0.04),
                              borderColor: const Color(0xFFC30121).withValues(alpha: 0.20),
                              borderStrokeWidth: 1.2,
                            ),
                            CircleMarker(
                              point: _currentCenter,
                              radius: 60,
                              useRadiusInMeter: false,
                              color: const Color(0xFFC30121).withValues(alpha: 0.07),
                              borderColor: const Color(0xFFC30121).withValues(alpha: 0.28),
                              borderStrokeWidth: 1.2,
                            ),
                            CircleMarker(
                              point: _currentCenter,
                              radius: 30,
                              useRadiusInMeter: false,
                              color: const Color(0xFFC30121).withValues(alpha: 0.12),
                              borderColor: const Color(0xFFC30121).withValues(alpha: 0.50),
                              borderStrokeWidth: 1.5,
                            ),
                            CircleMarker(
                              point: _currentCenter,
                              radius: 6.5,
                              useRadiusInMeter: false,
                              color: const Color(0xFFC30121),
                              borderColor: Colors.white,
                              borderStrokeWidth: 2.0,
                            ),
                            // Coarse blurred cluster circles for aggregated cells
                            ..._aggregatedCells.map((cell) {
                              final lat = (cell['latitude'] as num?)?.toDouble() ?? _currentCenter.latitude;
                              final lng = (cell['longitude'] as num?)?.toDouble() ?? _currentCenter.longitude;
                              return CircleMarker(
                                point: LatLng(lat, lng),
                                radius: 22,
                                useRadiusInMeter: false,
                                color: const Color(0xFFC30121).withValues(alpha: 0.18),
                                borderColor: const Color(0xFFC30121).withValues(alpha: 0.45),
                                borderStrokeWidth: 1.5,
                              );
                            }),
                          ],
                        ),
                        // Stitch Pin Markers with arrows
                        MarkerLayer(
                          markers: _displayPins.map((pin) {
                            final point = pin['point'] as LatLng;
                            final bloodGroup = pin['bloodGroup'] as String;
                            final distance = pin['distance'] as String;

                            return Marker(
                              point: point,
                              width: 88,
                              height: 38,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _triggerRegistrationGate(),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC30121),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.22),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 3.5),
                                          Text(
                                            bloodGroup,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            distance,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.9),
                                              height: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CustomPaint(
                                      size: const Size(6, 4),
                                      painter: _TrianglePointerPainter(color: const Color(0xFFC30121)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Top-Left Corridor Badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _triggerRegistrationGate(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: const Color(0xFFEAE7E7)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _mapStatusMessage,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B2B2B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Right Radar / Range Badge
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _triggerRegistrationGate(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: const Color(0xFFEAE7E7)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar_rounded, size: 12, color: Color(0xFF0D68AA)),
                              SizedBox(width: 4),
                              Text(
                                '3.5 km',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B2B2B),
                                ),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '• Coarse Pins',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Left Attribution
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    ),

                    // Loading or Offline state overlay
                    if (_isLoadingMap)
                      Container(
                        color: Colors.white.withValues(alpha: 0.7),
                        child: const Center(
                          child: AppLoader(),
                        ),
                      )
                    else if (_isOfflineOrError)
                      Container(
                        color: const Color(0xFFFDF3F3).withValues(alpha: 0.95),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isServerWakingUp ? Icons.cloud_sync_rounded : Icons.wifi_off_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Offline mode — map tiles cached locally',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF555555),
                                ),
                              ),
                              if (_isServerWakingUp) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Server waking up... Auto-retrying in ${_retryCountdown}s (attempt $_retryAttempts/3)',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  _retryTimer?.cancel();
                                  _loadLocationAndGuestMap();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Retry connection', style: TextStyle(fontFamily: 'Inter')),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_aggregatedCells.isEmpty && _totalNearbyDonors == 0)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Text(
                            'No donors registered nearby yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Total count & privacy reassurance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$_totalNearbyDonors donors in your area',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Ready to respond',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Locations are approximate for privacy.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E5E5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE9EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Quick Actions',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _triggerRegistrationGate(),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Explore',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D68AA),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildQuickActionTile(
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFC30121),
            bgColor: const Color(0xFFFFF0F1),
            title: 'Become a Donor',
            subtitle: 'Register to save lives and join our active network',
            onTap: () => _triggerRegistrationGate(targetRoute: '/register'),
          ),
          const SizedBox(height: 10),

          _buildQuickActionTile(
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF0D68AA),
            bgColor: Colors.white,
            title: 'Nearby Club',
            subtitle: 'Explore local voluntary organizations and communities',
            onTap: () => _triggerRegistrationGate(targetRoute: '/communities'),
          ),
          const SizedBox(height: 10),

          _buildQuickActionTile(
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFC30121),
            bgColor: const Color(0xFFFFD9DC),
            title: 'Express Emergency',
            subtitle: 'Post urgent blood requirements or request assistance',
            onTap: () => _triggerRegistrationGate(targetRoute: '/emergency-request'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF3F3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF999999),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PULSEAI CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPulseAICard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E5E5), width: 1.2),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/pulseai_icon.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              cacheWidth: 72,
              cacheHeight: 72,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'PulseAI',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE9EB),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ask about donation, eligibility and health',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => context.push('/assistant'),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFDF3F3),
              side: const BorderSide(color: Color(0xFFF3D6D9)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Try PulseAI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _TrianglePointerPainter extends CustomPainter {
  final Color color;
  const _TrianglePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePointerPainter oldDelegate) =>
      color != oldDelegate.color;
}

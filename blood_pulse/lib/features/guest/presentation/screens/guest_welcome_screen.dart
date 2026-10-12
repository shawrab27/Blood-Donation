import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../core/access/access_guard.dart';
import '../../../../services/api_client.dart';
import '../../../../widgets/pulseai_fab.dart';

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
  String _mapStatusMessage = 'Showing Bangladesh';
  int _totalNearbyDonors = 0;
  List<Map<String, dynamic>> _aggregatedCells = [];

  @override
  void initState() {
    super.initState();
    _loadLocationAndGuestMap();
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
    final response = await _apiClient
        .get('donors/guest-map/')
        .timeout(const Duration(milliseconds: 100));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load guest map (${response.statusCode})');
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
        setState(() {
          _totalNearbyDonors = count;
          _aggregatedCells = rawCells
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoadingMap = false;
        });
        try {
          _mapController.move(_currentCenter, _currentZoom);
        } catch (_) {}
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOfflineOrError = true;
          _isLoadingMap = false;
        });
        try {
          _mapController.move(_currentCenter, _currentZoom);
        } catch (_) {}
      }
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F3),
      appBar: const CustomAppBar(
        showBackButton: false,
        showProfile: true,
      ),
      floatingActionButton: const PulseAIFAB(),
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
                  const SizedBox(height: 16),

                  // ── Locked Row: Blood Hub, Chat & Profile ─────────────────
                  _buildLockedFeaturesCard(),
                  const SizedBox(height: 32),
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
  Widget _buildNearbyDonorsMapCard() {
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
                  Icons.near_me_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Nearby Donors',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF8F1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1B8A4E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _mapStatusMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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

          // Map View Container
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCenter,
                      initialZoom: _currentZoom,
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
                          CircleMarker(
                            point: _currentCenter,
                            radius: 35,
                            useRadiusInMeter: false,
                            color: const Color(0xFFC30121).withValues(alpha: 0.12),
                            borderColor: const Color(0xFFC30121),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: _aggregatedCells.map((cell) {
                          final lat = (cell['latitude'] as num?)?.toDouble() ?? _currentCenter.latitude;
                          final lng = (cell['longitude'] as num?)?.toDouble() ?? _currentCenter.longitude;
                          final count = (cell['count'] as num?)?.toInt() ?? 1;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 68,
                            height: 34,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC30121),
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.water_drop_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 6,
                    bottom: 4,
                    left: 6,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '© OpenStreetMap contributors',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Loading or Empty or Offline state overlay
                  if (_isLoadingMap)
                    Container(
                      color: Colors.white.withValues(alpha: 0.7),
                      child: const Center(
                        child: AppLoader(),
                      ),
                    )
                  else if (_isOfflineOrError)
                    Container(
                      color: const Color(0xFFFDF3F3).withValues(alpha: 0.9),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, color: AppColors.primary, size: 28),
                            const SizedBox(height: 6),
                            const Text(
                              'Offline mode — map tiles cached locally',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF555555),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadLocationAndGuestMap,
                              child: const Text('Retry connection', style: TextStyle(fontFamily: 'Inter')),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_aggregatedCells.isEmpty)
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
                    fontSize: 15,
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
                    fontWeight: FontWeight.w600,
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
              color: Color(0xFF888888),
            ),
          ),
        ],
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
              const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
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
              const Text(
                'Explore',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D68AA),
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
            onTap: () => _triggerGatedAction(AccessFeature.bloodHub, targetRoute: '/register'),
          ),
          const SizedBox(height: 10),

          _buildQuickActionTile(
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF0D68AA),
            bgColor: Colors.white,
            title: 'Nearby Club',
            subtitle: 'Explore local voluntary organizations and communities',
            onTap: () => _triggerGatedAction(AccessFeature.community, targetRoute: '/communities'),
          ),
          const SizedBox(height: 10),

          _buildQuickActionTile(
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFC30121),
            bgColor: const Color(0xFFFFD9DC),
            title: 'Express Emergency',
            subtitle: 'Post urgent blood requirements or request assistance',
            onTap: () => _triggerGatedAction(AccessFeature.bloodHub, targetRoute: '/emergency-request'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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

  // ───────────────────────────────────────────────────────────────────────────
  // LOCKED FEATURES CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLockedFeaturesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF7CCD3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC30121).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _triggerGatedAction(AccessFeature.bloodHub),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Blood Hub, Chat & Profile',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF999999),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Complete your registration to see all features\nসব ফিচার দেখতে রেজিস্ট্রেশন সম্পূর্ণ করুন',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Register now button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _triggerGatedAction(AccessFeature.bloodHub, targetRoute: '/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Register now / রেজিস্ট্রেশন করুন',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Log in link
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/login'),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../services/api_client.dart';
import '../../../../services/location_mapping_service.dart';

enum MapTrackingMode {
  radar,
  donor,
  requester,
}

/// Interactive OpenStreetMap screen supporting:
/// 1. Radar View: Nearby donors explore mode with 6km radius.
/// 2. Donor View: En route to patient/hospital with live distance in km and arrival action.
/// 3. Requester View: Incoming donor live beacon countdown + direct "Call Donor" and "Chat with Donor".
class DonorMapScreen extends StatefulWidget {
  final String? initialMode;
  final String? patientName;
  final String? hospitalName;
  final String? bloodGroup;
  final String? donorName;
  final String? donorPhone;
  final double? destinationLat;
  final double? destinationLng;

  const DonorMapScreen({
    super.key,
    this.initialMode,
    this.patientName,
    this.hospitalName,
    this.bloodGroup,
    this.donorName,
    this.donorPhone,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen>
    with SingleTickerProviderStateMixin {
  late MapTrackingMode _mode;
  final MapController _mapController = MapController();
  final ApiClient _apiClient = ApiClient();

  // Location centers
  LatLng _center = const LatLng(23.8103, 90.4125); // Default Dhaka center
  late LatLng _hospitalLocation;
  late LatLng _donorTrackingLocation;

  // Polyline coordinates for tracking mode
  List<LatLng> _routePoints = [];
  int _routeProgressIndex = 0;
  Timer? _simulationTimer;

  // Radar Donors
  List<DonorPin> _nearbyDonors = [];
  bool _isLoading = true;
  bool _hasArrived = false;

  // Animation controller for pulsing beacon
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Determine initial mode
    if (widget.initialMode == 'donor') {
      _mode = MapTrackingMode.donor;
    } else if (widget.initialMode == 'requester') {
      _mode = MapTrackingMode.requester;
    } else {
      _mode = MapTrackingMode.radar;
    }

    _hospitalLocation = LatLng(
      widget.destinationLat ?? 23.7259,
      widget.destinationLng ?? 90.3976,
    ); // Dhaka Medical College Hospital area
    _donorTrackingLocation = const LatLng(23.7808, 90.4192); // Gulshan / Badda area

    _setupRoutePoints();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadDonors();
    _startLiveTrackingSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _setupRoutePoints() {
    // Generated route coordinates leading to the hospital
    _routePoints = [
      const LatLng(23.7808, 90.4192),
      const LatLng(23.7712, 90.4140),
      const LatLng(23.7580, 90.4080),
      const LatLng(23.7485, 90.4020),
      const LatLng(23.7380, 90.3995),
      _hospitalLocation,
    ];
    _donorTrackingLocation = _routePoints.first;
    _routeProgressIndex = 0;
  }

  void _startLiveTrackingSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_mode == MapTrackingMode.radar) return;

      if (_routeProgressIndex < _routePoints.length - 1) {
        setState(() {
          _routeProgressIndex++;
          _donorTrackingLocation = _routePoints[_routeProgressIndex];
        });
      } else {
        // Loop back or mark arrived
        if (!_hasArrived && _mode == MapTrackingMode.donor) {
          setState(() {
            _hasArrived = true;
          });
        }
      }
    });
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadDonors() async {
    setState(() => _isLoading = true);

    final position = await _determinePosition();
    if (position != null) {
      _center = LatLng(position.latitude, position.longitude);
      if (_mode == MapTrackingMode.donor) {
        _donorTrackingLocation = _center;
      }
    }

    try {
      final response = await _apiClient.get(
        'donors-nearby/?lat=${_center.latitude}&lng=${_center.longitude}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetchedDonors = <DonorPin>[];

        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final lat = (item['latitude'] as num?)?.toDouble();
            final lng = (item['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              final rawLocation = LatLng(lat, lng);
              final fuzzedLocation =
                  LocationMappingService.instance.fuzzLocation(rawLocation);
              final firstName = item['first_name']?.toString() ?? '';
              final lastName = item['last_name']?.toString() ?? '';
              final fullName = ('$firstName $lastName').trim();
              fetchedDonors.add(
                DonorPin(
                  id: item['id']?.toString() ??
                      'donor_${fetchedDonors.length}',
                  location: fuzzedLocation,
                  bloodGroup: item['blood_group'] ?? 'O+',
                  isVerified: item['is_verified'] ?? false,
                  isAvailable: item['is_available'] ?? true,
                  name: fullName.isNotEmpty
                      ? fullName
                      : (item['username']?.toString() ?? 'Community Donor'),
                  phone: item['phone_number']?.toString(),
                ),
              );
            }
          }
        }

        if (mounted) {
          setState(() {
            _nearbyDonors = fetchedDonors.isNotEmpty
                ? fetchedDonors
                : LocationMappingService.instance
                    .fetchNearbyDonors(_center, radiusKm: 6.0);
            _isLoading = false;
          });
          _mapController.move(_center, 13.0);
        }
      } else {
        if (mounted) {
          setState(() {
            _nearbyDonors = LocationMappingService.instance
                .fetchNearbyDonors(_center, radiusKm: 6.0);
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _nearbyDonors = LocationMappingService.instance
              .fetchNearbyDonors(_center, radiusKm: 6.0);
          _isLoading = false;
        });
      }
    }
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, p1, p2);
  }

  int _calculateEtaMinutes(double distanceKm) {
    // Approximate city traffic: ~20 km/h = 3 mins per km
    final mins = (distanceKm * 3.2).round();
    return mins < 1 ? 1 : mins;
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calling $cleanPhone...'),
              backgroundColor: AppColors.tertiary,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not dial $cleanPhone automatically.'),
            backgroundColor: AppColors.tertiary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm =
        _calculateDistanceKm(_donorTrackingLocation, _hospitalLocation);
    final etaMinutes = _calculateEtaMinutes(distanceKm);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const CustomAppBar(
        showLogo: true,
        showBackButton: true,
      ),
      body: ResponsiveCenterWrapper(
        child: Stack(
          children: [
            // Map Layer
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mode == MapTrackingMode.radar
                    ? _center
                    : _donorTrackingLocation,
                initialZoom: 13.5,
                maxZoom: 18.0,
                minZoom: 10.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.bloodpulse.app',
                ),

                // Radar mode 6km circle
                if (_mode == MapTrackingMode.radar)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center,
                        color: AppColors.primary.withAlpha(35),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                        radius: 6000,
                      ),
                    ],
                  ),

                // Tracking route polyline (Donor & Requester modes)
                if (_mode != MapTrackingMode.radar)
                  PolylineLayer(
                    polylines: [
                      // Remaining route
                      Polyline(
                        points: [
                          _donorTrackingLocation,
                          ..._routePoints.sublist(_routeProgressIndex),
                        ],
                        color: _mode == MapTrackingMode.donor
                            ? AppColors.primary
                            : AppColors.tertiary,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),

                // Nearby Donors (Radar Mode)
                if (_mode == MapTrackingMode.radar)
                  MarkerLayer(
                    markers: _nearbyDonors.map((donor) {
                      return Marker(
                        point: donor.location,
                        width: 48,
                        height: 48,
                        child: _buildDonorMarker(donor),
                      );
                    }).toList(),
                  ),

                // Destination Hospital Marker (Tracking Modes & Radar Center)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _mode == MapTrackingMode.radar
                          ? _center
                          : _hospitalLocation,
                      width: 58,
                      height: 58,
                      child: _buildHospitalMarker(),
                    ),
                  ],
                ),

                // Moving Donor Live Beacon Marker (Tracking Modes)
                if (_mode != MapTrackingMode.radar)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _donorTrackingLocation,
                        width: 68,
                        height: 68,
                        child: _buildLiveBeaconMarker(),
                      ),
                    ],
                  ),
              ],
            ),

            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),

            // Top Floating Mode Selector Tabs
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: _buildModeSelector(),
            ),

            // Bottom Tracking Cards (Donor / Requester / Radar HUD)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _buildBottomPanel(distanceKm, etaMinutes),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final target = _mode == MapTrackingMode.radar
              ? _center
              : _donorTrackingLocation;
          _mapController.move(target, 14.0);
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
      ),
    );
  }

  // ── Mode Selector ─────────────────────────────────────────────────────────
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildModeTab(
            mode: MapTrackingMode.radar,
            label: 'Radar',
            icon: Icons.radar_rounded,
          ),
          _buildModeTab(
            mode: MapTrackingMode.donor,
            label: 'Donor En Route',
            icon: Icons.directions_bike_rounded,
          ),
          _buildModeTab(
            mode: MapTrackingMode.requester,
            label: 'Live Tracking',
            icon: Icons.track_changes_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required MapTrackingMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
            if (mode != MapTrackingMode.radar) {
              _mapController.move(_donorTrackingLocation, 14.0);
            } else {
              _mapController.move(_center, 13.0);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppColors.secondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hospital Marker ───────────────────────────────────────────────────────
  Widget _buildHospitalMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            widget.hospitalName ?? 'Hospital',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(90),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  // ── Animated Live Beacon Marker ───────────────────────────────────────────
  Widget _buildLiveBeaconMarker() {
    final isDonor = _mode == MapTrackingMode.donor;
    final color = isDonor ? AppColors.primary : AppColors.tertiary;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring
            Container(
              width: 56 * _pulseAnimation.value,
              height: 56 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha((80 / _pulseAnimation.value).round()),
              ),
            ),
            // Inner pin
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(120),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isDonor
                      ? Icons.directions_bike_rounded
                      : Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Bottom Panels ─────────────────────────────────────────────────────────
  Widget _buildBottomPanel(double distanceKm, int etaMinutes) {
    switch (_mode) {
      case MapTrackingMode.donor:
        return _buildDonorEnRoutePanel(distanceKm, etaMinutes);
      case MapTrackingMode.requester:
        return _buildRequesterTrackingPanel(distanceKm, etaMinutes);
      case MapTrackingMode.radar:
        return _buildRadarHud();
    }
  }

  // ── 1. Donor View Bottom Panel (En Route) ─────────────────────────────────
  Widget _buildDonorEnRoutePanel(double distanceKm, int etaMinutes) {
    final hospital = widget.hospitalName ?? 'Dhaka Medical College Hospital';
    final patient = widget.patientName ?? 'Emergency Patient';
    final bg = widget.bloodGroup ?? 'O+';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live status badge
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE DONOR EN ROUTE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withAlpha(60)),
                ),
                child: Text(
                  '$bg Urgent',
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
          const SizedBox(height: 12),

          // Destination Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patient: $patient • Ward 4, Emergency Unit',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Metrics bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  icon: Icons.navigation_rounded,
                  label: 'Distance',
                  value: '${distanceKm.toStringAsFixed(1)} km',
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                _buildMetricItem(
                  icon: Icons.timer_rounded,
                  label: 'Est. Time',
                  value: '~$etaMinutes mins',
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade300),
                _buildMetricItem(
                  icon: Icons.speed_rounded,
                  label: 'Traffic',
                  value: 'Moderate',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Button: Mark Arrived
          CapsuleButton(
            label: _hasArrived ? 'Arrived at Destination' : 'Mark as Arrived',
            icon: _hasArrived
                ? Icons.check_circle_rounded
                : Icons.check_rounded,
            onPressed: () {
              _showArrivalConfirmationDialog();
            },
          ),
        ],
      ),
    );
  }

  // ── 2. Requester View Bottom Panel (Tracking Incoming Donor) ──────────────
  Widget _buildRequesterTrackingPanel(double distanceKm, int etaMinutes) {
    final donorName = widget.donorName ?? 'Rahim Chowdhury';
    final donorPhone = widget.donorPhone ?? '01712345678';
    final bg = widget.bloodGroup ?? 'O+';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Countdown Banner
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'INCOMING DONOR TRACKING',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.tertiary,
                ),
              ),
              const Spacer(),
              Text(
                '${distanceKm.toStringAsFixed(1)} km away',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Countdown announcement banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.alarm_on_rounded,
                    color: AppColors.tertiary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                      children: [
                        const TextSpan(text: 'Estimated Arrival in '),
                        TextSpan(
                          text: '~$etaMinutes minutes',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.tertiary,
                          ),
                        ),
                        const TextSpan(text: ' • Traveling via bike'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Donor Profile Details
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Center(
                  child: Text(
                    bg,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            donorName,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 16, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Verified Hero Donor • 5+ Donations',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Direct Actions: Call Donor & Chat with Donor
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _makePhoneCall(donorPhone),
                  icon: const Icon(Icons.phone_rounded,
                      size: 18, color: AppColors.success),
                  label: const Text(
                    'Call Donor',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.success, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CapsuleButton(
                  label: 'Chat with Donor',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () {
                    context.push(
                      '/chat',
                      extra: {
                        'chatRecipientName': donorName,
                        'bloodGroup': bg,
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Radar HUD ──────────────────────────────────────────────────────────
  Widget _buildRadarHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.radar_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            '${_nearbyDonors.length} Active Donors Nearby within 6km',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.neutral),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDonorMarker(DonorPin donor) {
    return GestureDetector(
      onTap: () => _showDonorProfileSheet(context, donor),
      child: Container(
        decoration: BoxDecoration(
          color: donor.isAvailable
              ? (donor.isVerified ? AppColors.primary : AppColors.tertiary)
              : Colors.grey.shade500,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            donor.bloodGroup,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _showArrivalConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Confirm Arrival',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        content: Text(
          'Have you arrived at ${widget.hospitalName ?? "Dhaka Medical College Hospital"}? We will notify the patient and hospital team.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not Yet',
                style: TextStyle(
                    fontFamily: 'Inter', color: AppColors.neutral)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _hasArrived = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Arrival confirmed! Patient & family have been notified.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
            ),
            child: const Text('Yes, Arrived',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDonorProfileSheet(BuildContext context, DonorPin donor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E9),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      donor.bloodGroup,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donor.name ?? 'Community Donor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (donor.isVerified) ...[
                            const Icon(Icons.verified_rounded,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 4),
                            const Text(
                              'Verified Donor',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.shield_outlined,
                                size: 15, color: AppColors.neutral),
                            const SizedBox(width: 4),
                            const Text(
                              'Registered Donor',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.neutral,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: donor.isAvailable
                        ? const Color(0xFFE8F8F0)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: donor.isAvailable
                              ? AppColors.success
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        donor.isAvailable ? 'Available' : 'Resting',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: donor.isAvailable
                              ? AppColors.success
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded,
                      size: 16, color: AppColors.neutral),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location randomized by ~500m to protect donor home privacy.',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: AppColors.neutral),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CapsuleButton(
                    label: 'Message',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push(
                        '/chat',
                        extra: {
                          'chatRecipientName': donor.name,
                          'bloodGroup': donor.bloodGroup,
                        },
                      );
                    },
                  ),
                ),
                if (donor.phone != null && donor.phone!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F8F0),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.phone_rounded,
                        color: AppColors.success),
                    tooltip: 'Call Donor',
                    onPressed: () => _makePhoneCall(donor.phone!),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


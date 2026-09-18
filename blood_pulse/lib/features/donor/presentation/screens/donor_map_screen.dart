import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../services/api_client.dart';
import '../../../../services/location_mapping_service.dart';

/// Interactive OpenStreetMap showing nearby donors fetched via GET /api/donors-nearby/.
class DonorMapScreen extends StatefulWidget {
  const DonorMapScreen({super.key});

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  LatLng _center = const LatLng(23.8103, 90.4125);
  final MapController _mapController = MapController();
  final ApiClient _apiClient = ApiClient();

  List<DonorPin> _nearbyDonors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
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
              fetchedDonors.add(
                DonorPin(
                  id: item['id']?.toString() ?? 'donor_${fetchedDonors.length}',
                  location: fuzzedLocation,
                  bloodGroup: item['blood_group'] ?? 'O+',
                  isVerified: item['is_verified'] ?? false,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const CustomAppBar(
        showLogo: true,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              maxZoom: 18.0,
              minZoom: 10.0,
            ),
            children: [
              // Premium CartoDB Positron Base Map (Unchanged)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bloodpulse.app',
              ),

              // Target emergency center radius circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    color: AppColors.primary.withAlpha(40),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: 6000, // 6km radius
                  ),
                ],
              ),

              // Donor Markers from Backend / Spatial Query
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

              // User / Center Marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.local_hospital_rounded,
                        color: AppColors.primary, size: 40),
                  ),
                ],
              ),
            ],
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // HUD Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildHud(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _loadDonors();
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location_rounded, color: AppColors.primary),
      ),
    );
  }

  Widget _buildDonorMarker(DonorPin donor) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Selected Donor: ${donor.bloodGroup} (Privacy radius applied)'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: donor.isVerified ? AppColors.tertiary : Colors.grey.shade600,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            donor.bloodGroup,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radar_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            '${_nearbyDonors.length} Active Donors Nearby',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

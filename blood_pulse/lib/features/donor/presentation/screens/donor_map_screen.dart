import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../services/api_client.dart';
import '../../../../services/location_mapping_service.dart';
import 'package:go_router/go_router.dart';

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
              final firstName = item['first_name']?.toString() ?? '';
              final lastName = item['last_name']?.toString() ?? '';
              final fullName = ('$firstName $lastName').trim();
              fetchedDonors.add(
                DonorPin(
                  id: item['id']?.toString() ?? 'donor_${fetchedDonors.length}',
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
                            const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
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
                            const Icon(Icons.shield_outlined, size: 15, color: AppColors.neutral),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: donor.isAvailable ? const Color(0xFFE8F8F0) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: donor.isAvailable ? AppColors.success : Colors.grey,
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
                          color: donor.isAvailable ? AppColors.success : Colors.grey.shade700,
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
                  Icon(Icons.security_rounded, size: 16, color: AppColors.neutral),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location randomized by ~500m to protect donor home privacy.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.neutral),
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
                      context.push('/chat');
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
                    icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                    tooltip: 'Call Donor',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Calling ${donor.name} (${donor.phone})...'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
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

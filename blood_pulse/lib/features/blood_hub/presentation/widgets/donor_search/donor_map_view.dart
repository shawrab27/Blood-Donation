import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../data/blood_hub_api_service.dart';

/// Real Interactive OpenStreetMap Raster Map conforming to Stitch "Nearby Donor Network" UI.
/// Displays fuzzed donor pins (~500m per Rule 7) with 2D/3D overlays, zoom controls,
/// and an interactive donor card popup when any pin is tapped.
class DonorMapView extends ConsumerStatefulWidget {
  const DonorMapView({super.key});

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  ConsumerState<DonorMapView> createState() => _DonorMapViewState();
}

class _DonorMapViewState extends ConsumerState<DonorMapView> {
  final MapController _mapController = MapController();
  bool _isSatellite = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenter(LatLng center) {
    _mapController.move(center, 13.0);
  }

  @override
  Widget build(BuildContext context) {
    final pinsAsync = ref.watch(donorMapPinsProvider);

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6BDBA), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: pinsAsync.when(
        data: (pins) {
          final defaultCenter = pins.isNotEmpty
              ? LatLng(pins.first.lat, pins.first.lng)
              : const LatLng(23.7259, 90.3976); // Dhaka Center

          final markers = pins.map((pin) {
            return Marker(
              point: LatLng(pin.lat, pin.lng),
              width: 50,
              height: 52,
              child: GestureDetector(
                onTap: () => _showPinDonorPopup(context, pin),
                child: _DonorMapPinWidget(
                  bloodGroup: pin.bloodGroup,
                  isVerified: pin.isVerified,
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: defaultCenter,
                  initialZoom: 12.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: DonorMapView._osmTileUrl,
                    userAgentPackageName: 'com.bloodpulse.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // Top Overlay: 2D LIVE NETWORK Chip & View Mode Toggle
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFE6BDBA)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x10000000), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC30121),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${pins.length} LIVE DONORS',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF24191A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFE6BDBA)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x10000000), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isSatellite = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: !_isSatellite ? const Color(0xFF960017) : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            '2D View',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: !_isSatellite ? Colors.white : const Color(0xFF5F5E5E),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isSatellite = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isSatellite ? const Color(0xFF960017) : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            'Satellite',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isSatellite ? Colors.white : const Color(0xFF5F5E5E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Right Map Controls: Zoom in, Zoom out, Recenter
              Positioned(
                bottom: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapActionButton(
                      icon: Icons.add,
                      onTap: _zoomIn,
                    ),
                    const SizedBox(height: 6),
                    _MapActionButton(
                      icon: Icons.remove,
                      onTap: _zoomOut,
                    ),
                    const SizedBox(height: 6),
                    _MapActionButton(
                      icon: Icons.my_location_rounded,
                      onTap: () => _recenter(defaultCenter),
                    ),
                  ],
                ),
              ),

              // Visible OSM attribution per Rule 9
              Positioned(
                bottom: 4,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 8, color: Color(0xFF5F5E5E)),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: AppLoader(),
        ),
        error: (err, _) => Center(
          child: Text(
            'Unable to load live donor map: $err',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.red),
          ),
        ),
      ),
    );
  }

  /// Popup card when a map pin is tapped
  void _showPinDonorPopup(BuildContext context, DonorMapPin pin) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pin.name ?? 'Nearby Donor',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE9EB),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        pin.bloodGroup,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF960017),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${pin.campus ?? pin.district ?? 'Dhaka'} • Fuzzed radius (~500m)',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(
                        '/blood-hub/request/direct',
                        extra: {
                          'prefill_blood_group': pin.bloodGroup,
                          'prefill_district': pin.district,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC30121),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Request Blood from this Donor'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DonorMapPinWidget extends StatelessWidget {
  const _DonorMapPinWidget({
    required this.bloodGroup,
    required this.isVerified,
  });

  final String bloodGroup;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFC30121),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bloodGroup,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 2),
                const Icon(Icons.check, size: 10, color: Colors.white),
              ],
            ],
          ),
        ),
        const Icon(
          Icons.arrow_drop_down,
          size: 16,
          color: Color(0xFFC30121),
        ),
      ],
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE6BDBA)),
          boxShadow: const [
            BoxShadow(color: Color(0x18000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF24191A)),
      ),
    );
  }
}

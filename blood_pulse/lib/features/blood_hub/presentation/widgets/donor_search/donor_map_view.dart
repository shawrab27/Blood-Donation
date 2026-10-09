// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/blood_hub_api_service.dart';

/// Fuzzed (500m) OpenStreetMap view for nearby donors.
class DonorMapView extends ConsumerWidget {
  const DonorMapView({super.key});

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinsAsync = ref.watch(donorMapPinsProvider);

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DADA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: pinsAsync.when(
        data: (pins) {
          final markers = pins.map((pin) {
            return Marker(
              point: LatLng(pin.lat, pin.lng),
              width: 44,
              height: 44,
              child: _DonorMapPinWidget(bloodGroup: pin.bloodGroup),
            );
          }).toList();

          final initialCenter = pins.isNotEmpty
              ? LatLng(pins.first.lat, pins.first.lng)
              : const LatLng(23.7259, 90.3976); // Dhaka Center

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 12.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _osmTileUrl,
                    userAgentPackageName: 'org.bloodpulse.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFE8DADA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1B8A4E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${pins.length} Nearby Donors (Fuzzed ~500m)',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC30121)),
        ),
        error: (err, _) => Center(
          child: Text(
            'Unable to load donor map: $err',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.red),
          ),
        ),
      ),
    );
  }
}

class _DonorMapPinWidget extends StatelessWidget {
  const _DonorMapPinWidget({required this.bloodGroup});

  final String bloodGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFC30121),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            bloodGroup,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const Icon(
          Icons.arrow_drop_down,
          size: 14,
          color: Color(0xFFC30121),
        ),
      ],
    );
  }
}

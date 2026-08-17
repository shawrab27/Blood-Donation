import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Donor Map'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Stack(
        children: [
          // Simulated Map Background
          Container(
            color: AppColors.surfaceLight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                );
              },
            ),
          ),
          // Markers
          const Positioned(
            top: 200,
            left: 100,
            child: _DonorMarker(bloodGroup: 'A+', isAvailable: true),
          ),
          const Positioned(
            top: 150,
            right: 120,
            child: _DonorMarker(bloodGroup: 'O-', isAvailable: false),
          ),
          const Positioned(
            bottom: 300,
            left: 180,
            child: _DonorMarker(bloodGroup: 'B+', isAvailable: true),
          ),
          
          // Bottom Sheet UI
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppConstants.padding),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('12 Active Donors Nearby', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/request'),
                          icon: const Icon(Icons.campaign),
                          label: const Text('Broadcast Urgent Need'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.critical),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorMarker extends StatelessWidget {
  final String bloodGroup;
  final bool isAvailable;

  const _DonorMarker({required this.bloodGroup, required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable ? AppColors.success : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(bloodGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        Icon(Icons.location_on, color: isAvailable ? AppColors.success : Colors.grey, size: 32),
      ],
    );
  }
}

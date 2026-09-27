// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/shimmer_loading_widget.dart';
import '../../../../core/constants/constants.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../../../blood_hub/data/blood_hub_api_service.dart';

class ResourcesHubScreen extends ConsumerWidget {
  const ResourcesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(hospitalsDirectoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF271816),
      
      appBar: BloodPulseAppBar(
        backgroundColor: const Color(0xFF271816),
        subtitle: 'Resources Hub',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 8),

          const Text(
            'Verified Resources & Hotlines',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Direct access to national emergency blood hotlines, blood banks, and partnered hospital networks.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 20),

          // --- Section 1: Emergency Hotlines (Static) ---
          _sectionHeader('Emergency Hotlines'),
          const SizedBox(height: 12),
          Column(
            children: Constants.verifiedHotlines.map((contact) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _hotlineCard(
                  contact['title'],
                  contact['number'],
                  contact['subtitle'],
                  contact['icon'],
                  AppColors.primary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // --- Section 2: Hospital Network (Dynamic) ---
          _sectionHeader('Hospital Directory'),
          const SizedBox(height: 12),
          hospitalsAsync.when(
            loading: () => Column(
              children: List.generate(4, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: ShimmerLoadingWidget(height: 80, borderRadius: 20),
              )),
            ),
            error: (err, stack) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Error loading hospitals. Please try again.', style: TextStyle(fontFamily: 'Inter', color: AppColors.error)),
              ),
            ),
            data: (List<HospitalModel> hospitals) {
              if (hospitals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_hospital_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No hospitals available at the moment.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: hospitals.map((hospital) {
                  final displayName = hospital.name.isNotEmpty ? hospital.name : hospital.nameEn;
                  final displayLocation = hospital.address.isNotEmpty ? hospital.address : hospital.district;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _hospitalItem(
                      displayName.isNotEmpty ? displayName : 'Unknown Hospital',
                      displayLocation.isNotEmpty ? displayLocation : 'No location provided',
                      hospital.phone?.isNotEmpty == true ? hospital.phone! : 'No contact available',
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _hotlineCard(String title, String number, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalItem(String name, String location, String features) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0D68AA), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  features,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF0D68AA),
                    fontWeight: FontWeight.w500,
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

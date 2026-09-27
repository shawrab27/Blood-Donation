import os

filepath = 'lib/features/health_hub/presentation/screens/resources_hub_screen.dart'

new_screen = '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../../../../core/constants/emergency_hotlines.dart';

class ResourcesHubScreen extends ConsumerWidget {
  const ResourcesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(hospitalsDirectoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: BloodPulseAppBar(
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
            style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Direct access to national emergency blood hotlines, blood banks, and partnered hospital networks.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
          ),
          const SizedBox(height: 20),

          // —— Section 1: Emergency Hotlines (Static) ——
          _sectionHeader('Emergency Hotlines'),
          const SizedBox(height: 12),
          Column(
            children: EmergencyHotlines.verifiedHotlines.map((contact) {
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

          // —— Section 2: Hospital Network (Dynamic) ——
          _sectionHeader('Hospital Directory'),
          const SizedBox(height: 12),
          hospitalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => Center(child: Text('Error loading hospitals', style: TextStyle(fontFamily: 'Inter', color: AppColors.error))),
            data: (hospitals) {
              if (hospitals.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No hospitals available at the moment.',
                      style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral),
                    ),
                  ),
                );
              }
              return Column(
                children: hospitals.map((hospital) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _hospitalItem(
                      hospital.nameEn,
                      ', ',
                      hospital.phone ?? 'No contact available',
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
        color: AppColors.secondary,
      ),
    );
  }

  Widget _hotlineCard(String title, String number, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
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
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.neutral,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
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
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.neutral),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.neutral,
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
'''

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_screen)

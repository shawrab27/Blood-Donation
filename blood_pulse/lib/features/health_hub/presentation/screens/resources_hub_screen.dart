// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../core/widgets/shimmer_loading_widget.dart';
import '../../../../core/constants/constants.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../../../blood_hub/data/blood_hub_api_service.dart';

class ResourcesHubScreen extends ConsumerWidget {
  const ResourcesHubScreen({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot launch dialer for $phoneNumber', style: const TextStyle(fontFamily: 'Inter')),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call error: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(hospitalsDirectoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'Resources Hub',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── 1. Header ──────────────────────────────────────────────
            const Text(
              'Verified Resources & Hotlines',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Direct access to national emergency blood hotlines, blood banks, and partnered hospital networks.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 14),


            // ── 3. Emergency Hotlines ────────────────────────────────────
            _sectionHeader('Emergency Hotlines'),
            const SizedBox(height: 10),
            Column(
              children: Constants.verifiedHotlines.map((contact) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _hotlineCard(
                    context,
                    contact['title'],
                    contact['number'],
                    contact['subtitle'],
                    contact['icon'],
                    AppColors.primary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── 4. Hospital Network Directory ───────────────────────────
            _sectionHeader('Hospital Directory'),
            const SizedBox(height: 10),
            hospitalsAsync.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: ShimmerLoadingWidget(height: 76, borderRadius: 20),
                  ),
                ),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Unable to load hospitals directory.', style: const TextStyle(fontFamily: 'Inter', color: AppColors.error)),
                ),
              ),
              data: (List<HospitalModel> hospitals) {
                if (hospitals.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No hospitals currently listed.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
                    ),
                  );
                }
                return Column(
                  children: hospitals.map((hospital) {
                    final displayName = hospital.name.isNotEmpty ? hospital.name : hospital.nameEn;
                    final displayLocation = hospital.address.isNotEmpty ? hospital.address : hospital.district;
                    final phone = hospital.phone?.isNotEmpty == true ? hospital.phone! : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _hospitalItem(
                        context,
                        displayName.isNotEmpty ? displayName : 'Unknown Hospital',
                        displayLocation.isNotEmpty ? displayLocation : 'Location not specified',
                        phone,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }

  Widget _hotlineCard(BuildContext context, String title, String number, String subtitle, IconData icon, Color color) {
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
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.neutral)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall(context, number),
            icon: const Icon(Icons.call, size: 14),
            label: Text(number),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hospitalItem(BuildContext context, String name, String location, String phone) {
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.tertiary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.local_hospital_outlined, color: AppColors.tertiary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 2),
                Text(location, style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.neutral)),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary),
              onPressed: () => _makePhoneCall(context, phone),
            ),
        ],
      ),
    );
  }
}

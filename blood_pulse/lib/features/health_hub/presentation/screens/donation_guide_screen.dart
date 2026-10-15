import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../../domain/models/health_hub_models.dart';

class DonationGuideScreen extends ConsumerWidget {
  const DonationGuideScreen({super.key});

  static final List<DonationGuideSection> _fallbackGuides = [
    DonationGuideSection(
      id: 1,
      category: 'Before Donation (Preparation)',
      title: 'Hydration & Nutrition',
      content: 'Drink 500ml of water 30 minutes before donating. Eat a wholesome, low-fat meal rich in iron.',
    ),
    DonationGuideSection(
      id: 2,
      category: 'Before Donation (Preparation)',
      title: 'Adequate Rest',
      content: 'Ensure at least 6-8 hours of uninterrupted sleep the night before your scheduled donation.',
    ),
    DonationGuideSection(
      id: 3,
      category: 'During Donation (Procedure)',
      title: 'Relaxation & Comfort',
      content: 'Squeeze the donor stress ball rhythmically. Breathe steadily and let the phlebotomist know if you feel dizzy.',
    ),
    DonationGuideSection(
      id: 4,
      category: 'After Donation (Recovery)',
      title: 'Immediate Aftercare',
      content: 'Rest for 10-15 minutes at the observation station. Enjoy refreshments and keep the adhesive bandage on for 4 hours.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideAsyncValue = ref.watch(donationGuideProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'Donation Guide',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: guideAsyncValue.when(
            loading: () => const Center(child: AppLoader()),
            error: (_, __) => _buildGuideContent(_fallbackGuides),
            data: (guides) => _buildGuideContent(guides.isNotEmpty ? guides : _fallbackGuides),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideContent(List<DonationGuideSection> guides) {
    final Map<String, List<DonationGuideSection>> groupedGuides = {};
    for (var guide in guides) {
      groupedGuides.putIfAbsent(guide.category, () => []).add(guide);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. Hero Card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Guide to Giving Life',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
              SizedBox(height: 6),
              Text(
                'Everything you need to know before, during, and after donating blood to ensure a safe, comfortable experience.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.4),
              ),
            ],
          ),
        ),

        // ── 3. Categorized Sections ───────────────────────────────────
        ...groupedGuides.entries.map((entry) {
          final category = entry.key;
          final sections = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: sections.map((section) {
                    final isLast = section == sections.last;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      section.title,
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      section.content,
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF555555), height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast) const Divider(color: Color(0xFFEEEEEE)),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),
            ],
          );
        }),

        const SizedBox(height: 36),
      ],
    );
  }
}

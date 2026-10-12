import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';

import '../widgets/common/health_hub_subnav_bar.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../../domain/models/health_hub_models.dart';

class RecoveryAftercareScreen extends ConsumerStatefulWidget {
  const RecoveryAftercareScreen({super.key});

  @override
  ConsumerState<RecoveryAftercareScreen> createState() => _RecoveryAftercareScreenState();
}

class _RecoveryAftercareScreenState extends ConsumerState<RecoveryAftercareScreen> {
  int _waterGlasses = 6;

  static final List<RecoveryTimelineStep> _fallbackTimeline = [
    RecoveryTimelineStep(
      id: 1,
      hourMark: 24,
      title: 'Plasma Volume Replenishment',
      description: 'Your body restores 95% of lost fluid volume within 24 hours. Drink plenty of water and oral rehydration salts.',
      activityGuideline: 'Rest and drink fluids.',
      avoidList: 'Strenuous lifting.',
    ),
    RecoveryTimelineStep(
      id: 2,
      hourMark: 48,
      title: 'Red Blood Cell Synthesis',
      description: 'Bone marrow accelerates erythropoiesis. Maintain iron-rich foods such as spinach, lentils, and citrus.',
      activityGuideline: 'Eat iron-rich meals.',
      avoidList: 'Skipping meals.',
    ),
    RecoveryTimelineStep(
      id: 3,
      hourMark: 72,
      title: 'Iron Reserves Full Restoration',
      description: 'Ferritin reserves return to peak baseline levels. Complete your recovery cycle before the next voluntary donation.',
      activityGuideline: 'Normal routine.',
      avoidList: 'Donating before 90 days.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(recoveryTimelineProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'Recovery & Aftercare',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Top Subnav
            const HealthHubSubnavBar(activeRoute: '/health-hub/recovery'),

            // ── 1. Header ──────────────────────────────────────────────
            const Text(
              'Post-Donation Recovery Tracker',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track your body\'s plasma restoration and iron recovery timeline after donating blood.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 14),


            // ── 3. 24-Hour Progress Dial Card ───────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 108,
                        height: 108,
                        child: const AppLoader(),
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('85%', style: TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text('Recovered', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You are doing great!',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'It has been 24 hours since your donation. Plasma volume is 95% restored.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 4. Interactive Hydration Tracker ────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF4FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD0E4FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Daily Hydration Intake',
                          style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_waterGlasses / 8 Glasses',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_waterGlasses / 8.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white,
                      color: AppColors.tertiary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _waterGlasses > 0 ? () => setState(() => _waterGlasses--) : null,
                        icon: const Icon(Icons.remove, size: 16),
                        label: const Text('Remove', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFB0CDEE)),
                          foregroundColor: AppColors.tertiary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          minimumSize: const Size(48, 40),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _waterGlasses++),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+ Add 250ml Glass'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tertiary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
                          minimumSize: const Size(48, 40),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 5. Recovery Milestones Timeline ─────────────────────────
            const Text(
              'Biological Recovery Timeline',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            timelineAsync.when(
              loading: () => const Center(child: AppLoader()),
              error: (_, __) => _buildTimelineSteps(_fallbackTimeline),
              data: (steps) => _buildTimelineSteps(steps.isNotEmpty ? steps : _fallbackTimeline),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineSteps(List<RecoveryTimelineStep> steps) {
    return Column(
      children: steps.map((step) {
        final isCompleted = step.hourMark <= 24;
        final timeframe = step.hourMark > 0 ? '${step.hourMark} Hours' : 'Immediate';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFE8F8F0) : const Color(0xFFF3E5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                  color: isCompleted ? AppColors.success : const Color(0xFF6A1B9A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeframe,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutral),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF555555), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

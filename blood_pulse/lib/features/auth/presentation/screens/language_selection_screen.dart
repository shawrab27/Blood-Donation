import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../providers/locale_provider.dart';

/// Standalone Full-Screen Language Selection Screen matching Stitch UI design
/// (Screen ID: `932651e96b3e4020b93136bf15325c1f`).
///
/// Flow: Splash -> Onboarding (3 steps) -> Language Selection Screen -> Login Screen.
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final isBangla = locale.languageCode == 'bn';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          child: Column(
            children: [
              // ── Top Bar with Skip Action ─────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button if popped from previous flow
                    if (context.canPop())
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: Color(0xFF2B2B2B)),
                        onPressed: () => context.pop(),
                      )
                    else
                      const SizedBox.shrink(),

                    // Skip CTA Button
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF667085),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Text(
                        isBangla ? 'স্কিপ করুন' : 'Skip',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable Body with Brand + Selection Card ──────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ── Official BloodPulse Logo & Brand Name ─────────
                          const BloodPulseLogo(
                            direction: Axis.vertical,
                            iconSize: 58.0,
                            fontSize: 30.0,
                            spacing: 12.0,
                          ),
                          const SizedBox(height: 28),

                          // ── Language Selection White Card ────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 28),
                            child: Column(
                              children: [
                                // ── Bilingual Title ────────────────────────
                                const Text(
                                  'Select Language',
                                  style: TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B2B2B),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'ভাষা নির্বাচন করুন',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFC30121),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // ── Custom Capsule Toggle Pills ────────────
                                Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF3F3),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    children: [
                                      // English Tab
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: notifier.setEnglish,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            decoration: BoxDecoration(
                                              color: !isBangla
                                                  ? const Color(0xFFC30121)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              boxShadow: !isBangla
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.primary
                                                            .withAlpha(60),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'English',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: !isBangla
                                                    ? Colors.white
                                                    : const Color(0xFF667085),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Bangla Tab
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: notifier.setBangla,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            decoration: BoxDecoration(
                                              color: isBangla
                                                  ? const Color(0xFFC30121)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              boxShadow: isBangla
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.primary
                                                            .withAlpha(60),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              'বাংলা',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isBangla
                                                    ? Colors.white
                                                    : const Color(0xFF667085),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // ── Informational Subtitle ─────────────────
                                Text(
                                  isBangla
                                      ? 'রক্তদান সেবা চালিয়ে যেতে আপনার পছন্দের ভাষা নির্বাচন করুন।'
                                      : 'Choose your preferred language to proceed with donation services.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF667085),
                                    height: 1.45,
                                  ),
                                ),

                                const SizedBox(height: 26),

                                // ── Continue to Login Button ───────────────
                                SizedBox(
                                  width: double.infinity,
                                  child: CapsuleButton(
                                    label: isBangla
                                        ? 'এগিয়ে যান'
                                        : 'Continue / এগিয়ে যান',
                                    icon: Icons.arrow_forward_rounded,
                                    showGlow: true,
                                    onPressed: () {
                                      context.go('/login');
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Trust Footer ─────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: Color(0xFF888888),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isBangla
                                    ? 'বিশ্বজুড়ে ২০ লাখেরও বেশি রক্তদাতার বিশ্বস্ত প্ল্যাটফর্ম'
                                    : 'Trusted by 2M+ Donors Worldwide',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF888888),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

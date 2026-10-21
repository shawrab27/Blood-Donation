// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../core/widgets/language_toggle_button.dart';
import '../../../../core/localization/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingStepData {
  final String title;
  final String titleBn;
  final String description;
  final String descriptionBn;
  final String imagePath;
  final String stepBadge;
  final String stepBadgeBn;

  const OnboardingStepData({
    required this.title,
    required this.titleBn,
    required this.description,
    required this.descriptionBn,
    required this.imagePath,
    required this.stepBadge,
    required this.stepBadgeBn,
  });
}

const List<OnboardingStepData> _onboardingSteps = [
  OnboardingStepData(
    title: 'Donate Blood',
    titleBn: 'রক্তদান করুন',
    description:
        'Empower life through voluntary donation. Your single contribution can save up to three lives in emergency care.',
    descriptionBn:
        'স্বেচ্ছায় রক্তদানে জীবন বাঁচান। আপনার একটি অনুদান জরুরি চিকিৎসায় তিনজনের জীবন বাঁচাতে পারে।',
    imagePath: 'assets/images/onboarding_1.png',
    stepBadge: 'Step 1 of 3',
    stepBadgeBn: 'ধাপ ১/৩',
  ),
  OnboardingStepData(
    title: 'Save Lives',
    titleBn: 'জীবন বাঁচান',
    description:
        'Every drop matters. Connect instantly with local hospitals and patients facing critical emergencies to provide life-saving transfusions.',
    descriptionBn:
        'প্রতিটি রক্তবিন্দু মূল্যবান। জীবন রক্ষাকারী স্থানান্তরের জন্য সরাসরি স্থানীয় হাসপাতাল ও মুমূর্ষু রোগীর সাথে যুক্ত হন।',
    imagePath: 'assets/images/onboarding_2.png',
    stepBadge: 'Step 2 of 3',
    stepBadgeBn: 'ধাপ ২/৩',
  ),
  OnboardingStepData(
    title: 'Get Connected in Community',
    titleBn: 'কমিউনিটিতে যুক্ত হন',
    description:
        "Join Bangladesh's largest network of altruistic blood donors, student clubs, and volunteer organizations working together to save lives.",
    descriptionBn:
        'জীবন বাঁচাতে একসাথে কাজ করা রক্তদাতা, শিক্ষার্থী ক্লাব এবং স্বেচ্ছাসেবক সংগঠনের বৃহত্তম নেটওয়ার্কে যোগ দিন।',
    imagePath: 'assets/images/onboarding_3.png',
    stepBadge: 'Step 3 of 3',
    stepBadgeBn: 'ধাপ ৩/৩',
  ),
];

/// 3-Step Walkthrough Onboarding Screen matching Stitch UI design:
/// 1. Donate Blood
/// 2. Save Lives
/// 3. Get Connected in Community
class OnboardingScreen extends ConsumerStatefulWidget {
  final int initialStep;

  const OnboardingScreen({super.key, this.initialStep = 0});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final startStep = widget.initialStep.clamp(0, _onboardingSteps.length - 1);
    _currentIndex = startStep;
    _pageController = PageController(initialPage: startStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentIndex < _onboardingSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    context.go('/language');
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _currentIndex == _onboardingSteps.length - 1;
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/language');
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F7),
        body: SafeArea(
          child: ResponsiveCenterWrapper(
            child: Column(
              children: [
                // ── Top Bar (Language Toggle + Skip CTA) ────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const LanguageToggleButton(),

                      // Skip CTA Button (fades out on final step)
                      AnimatedOpacity(
                        opacity: isLastStep ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: isLastStep ? null : _finishOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF667085),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: Text(
                            isBangla ? 'এড়িয়ে যান' : 'Skip',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Carousel View of 3 Onboarding Steps ────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingSteps.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final step = _onboardingSteps[index];
                      return _buildSlidePage(step, index, isBangla);
                    },
                  ),
                ),

                // ── Bottom Navigation Area (Indicator Dots & Next/Get Started) ─
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step Indicator Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingSteps.length,
                          (index) => _buildIndicatorDot(index),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Primary Action Button
                      CapsuleButton(
                        label: isLastStep
                            ? (isBangla ? 'শুরু করুন' : 'Get Started')
                            : (isBangla ? 'পরবর্তী' : 'Next'),
                        showGlow: true,
                        onPressed: _onNext,
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidePage(OnboardingStepData step, int index, bool isBangla) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxHeight < 460;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: isSmall ? 6 : 12),

                  // Illustration Container
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: isSmall ? 150 : 240),
                    child: Image.asset(
                      step.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: isSmall ? 140 : 200,
                        height: isSmall ? 140 : 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8E9),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withAlpha(40), width: 2),
                        ),
                        child: Icon(
                          Icons.volunteer_activism_rounded,
                          color: AppColors.primary,
                          size: isSmall ? 48 : 70,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isSmall ? 10 : 16),

                  // Step Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      isBangla ? step.stepBadgeBn : step.stepBadge.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmall ? 8 : 14),

                  // Title (Georgia font, bold, dark charcoal)
                  Text(
                    isBangla ? step.titleBn : step.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: isSmall ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF202020),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: isSmall ? 6 : 12),

                  // Subtitle (Inter font, muted neutral, readable height)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      isBangla ? step.descriptionBn : step.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF667085),
                        height: 1.4,
                      ),
                    ),
                  ),

                  SizedBox(height: isSmall ? 10 : 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildIndicatorDot(int index) {
    final isActive = _currentIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : const Color(0xFFFFDADB),
        borderRadius: BorderRadius.circular(50),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(50),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}

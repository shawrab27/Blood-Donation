import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';

class OnboardingStepData {
  final String title;
  final String description;
  final String imagePath;
  final String stepBadge;

  const OnboardingStepData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.stepBadge,
  });
}

const List<OnboardingStepData> _onboardingSteps = [
  OnboardingStepData(
    title: 'Donate Blood',
    description:
        'Empower life through voluntary donation. Your single contribution can save up to three lives in emergency care.',
    imagePath: 'assets/images/onboarding_1.png',
    stepBadge: 'Step 1 of 3',
  ),
  OnboardingStepData(
    title: 'Save Lives',
    description:
        'Every drop matters. Connect instantly with local hospitals and patients facing critical emergencies to provide life-saving transfusions.',
    imagePath: 'assets/images/onboarding_2.png',
    stepBadge: 'Step 2 of 3',
  ),
  OnboardingStepData(
    title: 'Get Connected in Community',
    description:
        "Join Bangladesh's largest network of altruistic blood donors, student clubs, and volunteer organizations working together to save lives.",
    imagePath: 'assets/images/onboarding_3.png',
    stepBadge: 'Step 3 of 3',
  ),
];

/// 3-Step Walkthrough Onboarding Screen matching Stitch UI design:
/// 1. Donate Blood
/// 2. Save Lives
/// 3. Get Connected in Community
class OnboardingScreen extends StatefulWidget {
  final int initialStep;

  const OnboardingScreen({super.key, this.initialStep = 0});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          child: Column(
            children: [
              // ── Top Bar (BloodPulse Brand Title + Skip CTA) ────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo removed per user instruction
                    const SizedBox.shrink(),

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
                        child: const Text(
                          'Skip',
                          style: TextStyle(
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
                    return _buildSlidePage(step, index);
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
                      label: isLastStep ? 'Get Started' : 'Next >',
                      icon: isLastStep
                          ? Icons.arrow_forward_rounded
                          : Icons.chevron_right_rounded,
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
    );
  }

  Widget _buildSlidePage(OnboardingStepData step, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // Illustration Container
          Center(
            child: SizedBox(
              height: 290,
              child: Image.asset(
                step.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E9),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withAlpha(40), width: 2),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: AppColors.primary,
                    size: 80,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(flex: 1),

          // Step Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE9EB),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              step.stepBadge.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title (Georgia font, bold, dark charcoal)
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202020),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle (Inter font, muted neutral, readable height)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              step.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Color(0xFF667085),
                height: 1.5,
              ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
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

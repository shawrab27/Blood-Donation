import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/app_logo_slot.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../widgets/language_modal.dart';

/// BloodPulse Splash Screen
///
/// Features:
///   • Centered Stack with LayoutBuilder & ResponsiveLayout constraints.
///   • Pulsing [AppLogoSlot] with AnimationController scale + glow.
///   • Georgia "BloodPulse" title with fade-in.
///   • Exact Slogan: "You give today , They live today." with delayed fade-in.
///   • Centered #C30121 Capsule Button "Let's Start" — opens [LanguageModal] on tap.
///   • Footer Terms: "By continuing, you agree to our terms of clinical excellence and community altruism."
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Pulse animation ──────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _pulseScale = Tween<double>(
    begin: 0.92,
    end: 1.08,
  ).animate(CurvedAnimation(
    parent: _pulseCtrl,
    curve: Curves.easeInOut,
  ));

  // ── Glow opacity follows pulse ────────────────────────────────────────────
  late final Animation<double> _glowAnim = CurvedAnimation(
    parent: _pulseCtrl,
    curve: Curves.easeInOut,
  );

  // ── Fade-in for title + slogan + button + footer ─────────────────────────
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _fadeCtrl,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _sloganFade = CurvedAnimation(
    parent: _fadeCtrl,
    curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
  );

  late final Animation<double> _btnFade = CurvedAnimation(
    parent: _fadeCtrl,
    curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
  );

  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _fadeCtrl,
    curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onLetsStart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguageModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDF3F3), // surface
              Color(0xFFFEE9EB), // surface-container
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // ── Pulsing Logo ──────────────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, child) {
                    final scale = _pulseScale.value;
                    final glowOpacity = _glowAnim.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha((glowOpacity * 60).toInt()),
                              blurRadius: 30,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: const AppLogoSlot(size: AppLogoSize.splash, showShadow: false),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────
                FadeTransition(
                  opacity: _titleFade,
                  child: const Text(
                    'BloodPulse',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Slogan ────────────────────────────────────────────────
                FadeTransition(
                  opacity: _sloganFade,
                  child: const Text(
                    'You give today , They live today.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.secondary,
                      height: 1.5,
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // ── CTA Button ────────────────────────────────────────────
                FadeTransition(
                  opacity: _btnFade,
                  child: CapsuleButton(
                    label: "Let's Start",
                    icon: Icons.arrow_forward_rounded,
                    showGlow: true,
                    onPressed: _onLetsStart,
                  ),
                ),

                const Spacer(flex: 1),

                // ── Footer Terms ──────────────────────────────────────────
                FadeTransition(
                  opacity: _footerFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'By continuing, you agree to our terms of clinical excellence and community altruism.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.neutral.withAlpha(200),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

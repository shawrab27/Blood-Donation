import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../widgets/language_modal.dart';


/// BloodPulse Splash Screen supporting mobile/tablet app flow and web landing desktop view.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _titleFade;
  late final Animation<double> _sloganFade;
  late final Animation<double> _btnFade;
  late final Animation<double> _footerFade;


  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    ));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );

    _titleFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _sloganFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );

    _btnFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );

    _footerFade = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onLetsStartMobile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => const LanguageModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMobile(context),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF8F7), // surface
            Color(0xFFFDF3F3), // surface-container
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

              // ── Logo inside Card Container with Shadow ──
              ScaleTransition(
                scale: _pulseScale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/Blood Pulse logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Title ──
              FadeTransition(
                opacity: _titleFade,
                child: const Text(
                  'BloodPulse',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Slogan ──
              FadeTransition(
                opacity: _sloganFade,
                child: const Text(
                  'You give today , They live today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Red CTA Let's Start Button ──
              FadeTransition(
                opacity: _btnFade,
                child: CapsuleButton(
                  label: "Let's Start",
                  icon: Icons.arrow_forward_rounded,
                  showGlow: true,
                  onPressed: _onLetsStartMobile,
                ),
              ),

              const SizedBox(height: 16),

              // ── Dot Indicators ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFC30121),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFEE9EB),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFEE9EB),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // ── Footer Terms ──
              FadeTransition(
                opacity: _footerFade,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'By continuing, you agree to our terms of clinical excellence and community altruism.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF888888),
                      height: 1.4,
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


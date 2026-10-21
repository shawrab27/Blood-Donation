// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'features/auth/presentation/providers/auth_notifier.dart';
import 'core/access/access_guard.dart';

/// Splash screen that plays the official intro video asset before routing into the app.
class SplashVideoScreen extends ConsumerStatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  ConsumerState<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends ConsumerState<SplashVideoScreen> {
  VideoPlayerController? _controller;
  bool _hasNavigated = false;
  Timer? _fallbackTimer;
  late final Future<void> _restoreFuture;

  @override
  void initState() {
    super.initState();
    // Enable immersive full screen during splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _restoreFuture = ref.read(authProvider.notifier).restoreSession();
    _initializeAndPlayVideo();
  }

  Future<void> _initializeAndPlayVideo() async {
    // Initial safety fallback timer (7s ensures codec initialization plus playback)
    _fallbackTimer = Timer(const Duration(milliseconds: 7000), () {
      if (mounted && !_hasNavigated) {
        _navigateToNext();
      }
    });

    try {
      final controller = VideoPlayerController.asset(
        'assets/vedio/splash.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;

      // Allow 5000ms for ExoPlayer surface and media codec initialization
      await controller.initialize().timeout(const Duration(milliseconds: 5000));
      if (!mounted) return;

      controller.addListener(_videoListener);
      await controller.setLooping(false);
      // Mute audio so Web and mobile browser autoplay policies allow instant playback
      await controller.setVolume(0.0);
      await controller.play();

      // Cancel initial fallback timer and set it to video length + 600ms margin
      _fallbackTimer?.cancel();
      final totalMs = controller.value.duration.inMilliseconds;
      final safetyMs = (totalMs > 0 ? totalMs : 3000) + 600;
      _fallbackTimer = Timer(Duration(milliseconds: safetyMs), () {
        if (mounted && !_hasNavigated) {
          _navigateToNext();
        }
      });

      setState(() {});
    } catch (e) {
      debugPrint('[SplashVideoScreen] Video initialization failed or timed out: $e');
      if (mounted) {
        // Fallback gracefully to static logo splash without hanging
        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(milliseconds: 1400), _navigateToNext);
      }
    }
  }

  void _videoListener() {
    if (_hasNavigated || !mounted) return;

    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.duration > Duration.zero &&
        controller.value.position >= (controller.value.duration - const Duration(milliseconds: 100))) {
      _navigateToNext();
    }
  }

  Future<void> _navigateToNext() async {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _fallbackTimer?.cancel();

    // Restore standard UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Wait for session restoration to complete
    try {
      await _restoreFuture;
    } catch (_) {}

    if (!mounted) return;

    final currentPath = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    if (currentPath != '/' && currentPath != '/splash') return;

    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      context.go('/guest-welcome');
      return;
    }

    final authStatus = ref.read(authProvider).status;
    if (authStatus == AuthStatus.authenticated ||
        authStatus == AuthStatus.authenticatedIncomplete) {
      context.go('/feed');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _fallbackTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Exact background color of assets/vedio/splash.mp4: #F9EEEA
    const splashBgColor = Color(0xFFF9EEEA);
    final controller = _controller;
    final isInitialized = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: splashBgColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _navigateToNext, // Tap anywhere to skip
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Seamless Background Color Canvas ────────────────────────
              const ColoredBox(color: splashBgColor),

              // ── Fallback / Loading Brand Logo (shown immediately so no blank wait) ──
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/launcher_icon_transparent.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'BloodPulse',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC30121),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Every Drop Counts',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5C3F3D),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Responsive Video Player (centered, zero cropping on ANY screen) ──
              if (isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : (720 / 1280),
                    child: VideoPlayer(controller),
                  ),
                ),

              // ── Skip Button in Top-Right Corner ──────────────────────────
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToNext,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF24191A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF24191A).withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF24191A),
                        ),
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

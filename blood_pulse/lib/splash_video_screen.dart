// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'features/auth/presentation/providers/auth_notifier.dart';

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
    // Safety max timer (3.5s total) so the user is never stuck waiting
    _fallbackTimer = Timer(const Duration(milliseconds: 3500), () {
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

      // Timeout initialization to 1.8s so slow decoders do not hang the app
      await controller.initialize().timeout(const Duration(milliseconds: 1800));
      if (!mounted) return;

      controller.addListener(_videoListener);
      await controller.setLooping(false);
      await controller.play();

      setState(() {});
    } catch (e) {
      debugPrint('[SplashVideoScreen] Video initialization failed or timed out: $e');
      if (mounted) {
        Timer(const Duration(milliseconds: 800), _navigateToNext);
      }
    }
  }

  void _videoListener() {
    if (_hasNavigated || !mounted) return;

    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration) {
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
    const darkThemeBg = Color(0xFF271816);
    final controller = _controller;
    final isInitialized = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: darkThemeBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToNext, // Tap anywhere to skip
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Fallback / Loading Brand Logo (shown immediately so no blank wait) ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/Blood Pulse logo.jpg',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'BloodPulse',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Every Drop Counts',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFFE0E0E0),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // ── Full-Screen Video Player (smoothly overlays once ready) ──────
            if (isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),

            // Skip button in top-right corner
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              right: 16,
              child: TextButton(
                onPressed: _navigateToNext,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withAlpha(90),
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

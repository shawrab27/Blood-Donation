import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'services/api_client.dart';

/// Splash screen that plays the official intro video asset before routing into the app.
class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late VideoPlayerController _controller;
  bool _hasNavigated = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Enable immersive full screen during splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeAndPlayVideo();
  }

  Future<void> _initializeAndPlayVideo() async {
    _controller = VideoPlayerController.asset('assets/vedio/splash.mp4');

    try {
      await _controller.initialize();
      if (!mounted) return;

      _controller.addListener(_videoListener);
      await _controller.setLooping(false);
      await _controller.play();

      setState(() {});
    } catch (e) {
      debugPrint('[SplashVideoScreen] Video initialization failed: $e');
      if (mounted) {
        setState(() => _isError = true);
        // Fallback: navigate after a brief moment if video fails to initialize
        Timer(const Duration(milliseconds: 1200), _navigateToNext);
      }
    }
  }

  void _videoListener() {
    if (_hasNavigated || !mounted) return;

    final value = _controller.value;
    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _navigateToNext();
    }
  }

  Future<void> _navigateToNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Restore standard UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Check if user is already authenticated to choose next destination
    try {
      final token = await ApiClient().getAccessToken();
      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        context.go('/dashboard');
      } else {
        context.go('/onboarding');
      }
    } catch (_) {
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkThemeBg = Color(0xFF271816);

    return Scaffold(
      backgroundColor: darkThemeBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToNext, // Tap anywhere to skip
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-Screen Video Player ────────────────────────────────────
            SizedBox.expand(
              child: _controller.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : _isError
                      ? const SizedBox.shrink()
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFC30121),
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

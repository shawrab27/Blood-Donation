import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 3D ECG heartbeat perspective background with glowing waveform lines.
/// Features:
/// - Maximum opacity clamped <= 8% (subtle non-distracting background)
/// - Perspective grid floor receding to horizon
/// - Glowing ECG waveform lines travelling along the depth axis
/// - Dynamic pulse rate: subtle when idle, rapid & energetic when thinking
/// - Single controller with 30 fps throttling & RepaintBoundary isolation
/// - Lifecycle-aware pausing: stops ticker when backgrounded
/// - Pauses immediately when keyboard is open (viewInsets.bottom > 0)
/// - Pauses during fast scroll, resumes when settled
/// - Accessibility fallback (static frame when disableAnimations is enabled)
class Ecg3DBackground extends StatefulWidget {
  final bool isThinking;
  final Widget? child;

  const Ecg3DBackground({
    super.key,
    this.isThinking = false,
    this.child,
  });

  @override
  State<Ecg3DBackground> createState() => _Ecg3DBackgroundState();
}

class _Ecg3DBackgroundState extends State<Ecg3DBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  DateTime _lastFrameTime = DateTime.now();
  bool _isLowEndMode = false;
  int _consecutiveSlowFrames = 0;
  bool _isFastScrolling = false;
  Timer? _scrollPauseTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  void _onFastScrollDetected() {
    if (!_isFastScrolling) {
      if (mounted) {
        setState(() {
          _isFastScrolling = true;
        });
      }
    }
    _scrollPauseTimer?.cancel();
    _scrollPauseTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isFastScrolling = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating && !_isFastScrolling) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop(canceled: false);
      }
    }
  }

  @override
  void dispose() {
    _scrollPauseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final shouldPause = disableAnimations || isKeyboardOpen || _isFastScrolling;

    if (shouldPause) {
      if (_controller.isAnimating) {
        _controller.stop(canceled: false);
      }
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final delta = notification.scrollDelta?.abs() ?? 0.0;
          if (delta > 8.0) {
            _onFastScrollDetected();
          }
        }
        return false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Solid theme surface background
          Container(color: const Color(0xFFFDF3F3)),

          // Isolated 3D ECG custom painter with RepaintBoundary
          RepaintBoundary(
            child: shouldPause
                ? CustomPaint(
                    painter: _Ecg3DPainter(
                      phase: 0.25,
                      isThinking: false,
                      isLowEnd: true,
                    ),
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final now = DateTime.now();
                      final elapsed = now.difference(_lastFrameTime).inMilliseconds;

                      // Cap painting to ~30 FPS (33ms interval)
                      if (elapsed < 32) {
                        return CustomPaint(
                          painter: _Ecg3DPainter(
                            phase: _controller.value,
                            isThinking: widget.isThinking,
                            isLowEnd: _isLowEndMode,
                          ),
                        );
                      }

                      // Low-end device detection
                      if (elapsed > 45) {
                        _consecutiveSlowFrames++;
                        if (_consecutiveSlowFrames > 15) {
                          _isLowEndMode = true;
                        }
                      } else if (_consecutiveSlowFrames > 0) {
                        _consecutiveSlowFrames--;
                      }

                      _lastFrameTime = now;
                      return CustomPaint(
                        painter: _Ecg3DPainter(
                          phase: _controller.value,
                          isThinking: widget.isThinking,
                          isLowEnd: _isLowEndMode,
                        ),
                      );
                    },
                  ),
          ),

          // Soft subtle scrim to ensure WCAG AA text contrast
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFDF3F3).withValues(alpha: 0.65),
                    const Color(0xFFFDF3F3).withValues(alpha: 0.40),
                    const Color(0xFFFDF3F3).withValues(alpha: 0.70),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Child content (e.g. Chat list & bubbles)
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _Ecg3DPainter extends CustomPainter {
  final double phase;
  final bool isThinking;
  final bool isLowEnd;

  _Ecg3DPainter({
    required this.phase,
    required this.isThinking,
    required this.isLowEnd,
  });

  // Authentic ECG waveform normalized value (-0.3 to 1.0)
  // t is normalized cycle position [0.0, 1.0)
  double _ecgWave(double t) {
    t = t % 1.0;
    if (t < 0.0) t += 1.0;

    // Baseline quiet
    if (t < 0.12) return 0.0;

    // P-wave (smooth gentle atrial contraction)
    if (t < 0.22) {
      final pT = (t - 0.12) / 0.10;
      return 0.15 * math.sin(pT * math.pi);
    }

    // PR-segment
    if (t < 0.28) return 0.0;

    // Q-dip (sharp downward deflection)
    if (t < 0.31) {
      final qT = (t - 0.28) / 0.03;
      return -0.18 * math.sin(qT * math.pi);
    }

    // R-spike (primary massive ventricular contraction)
    if (t < 0.36) {
      final rT = (t - 0.31) / 0.05;
      if (rT < 0.45) {
        return (rT / 0.45) * 1.0;
      } else {
        return (1.0 - (rT - 0.45) / 0.55) * 1.0;
      }
    }

    // S-dip (sharp downward overshoot)
    if (t < 0.41) {
      final sT = (t - 0.36) / 0.05;
      return -0.28 * math.sin(sT * math.pi);
    }

    // ST-segment
    if (t < 0.48) return 0.0;

    // T-wave (smooth repolarization wave)
    if (t < 0.65) {
      final tT = (t - 0.48) / 0.17;
      return 0.32 * math.sin(tT * math.pi);
    }

    // Baseline rest until next beat
    return 0.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Horizon line positioned at ~36% screen height
    final horizonY = h * 0.36;
    final vanishingPoint = Offset(w * 0.5, horizonY);

    // Dynamic tempo: ~60 bpm idle vs ~130 bpm thinking
    final speedMultiplier = isThinking ? 3.0 : 1.2;
    final effectivePhase = (phase * speedMultiplier) % 1.0;
    final pulseGlowMultiplier = isThinking ? 1.5 : 1.0;

    // ─────────────────────────────────────────────────────────────────────────
    // 1. PERSPECTIVE FLOOR GRID RECEDING TO HORIZON
    // ─────────────────────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFFC30121).withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Vanishing radial lines
    const int longitudinalCount = 8;
    for (int i = -longitudinalCount; i <= longitudinalCount; i++) {
      final floorBottomX = (w * 0.5) + (i * (w * 0.09));
      canvas.drawLine(
        vanishingPoint,
        Offset(floorBottomX, h),
        gridPaint,
      );
    }

    // Receding horizontal transverse lines with quadratic perspective foreshortening
    const int transverseLines = 12;
    for (int i = 1; i <= transverseLines; i++) {
      final depth = math.pow(i / transverseLines, 2.2).toDouble();
      final y = horizonY + (h - horizonY) * depth;
      final alpha = (0.01 + 0.02 * depth).clamp(0.005, 0.03);
      final linePaint = Paint()
        ..color = const Color(0xFFC30121).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 + 0.6 * depth;

      final halfSpan = (w * 0.1) + (w * 0.55) * depth;
      canvas.drawLine(
        Offset((w * 0.5) - halfSpan, y),
        Offset((w * 0.5) + halfSpan, y),
        linePaint,
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. THREE PERSPECTIVE 3D ECG WAVEFORM LINES (opacity strictly <= 8%)
    // ─────────────────────────────────────────────────────────────────────────
    final tracks = isLowEnd
        ? [0.0] // Low-end fallback: single center track
        : [-0.38, 0.0, 0.38]; // 3 depth tracks

    const int depthSteps = 70;

    for (final trackOffset in tracks) {
      final path = Path();
      final glowPath = Path();

      bool started = false;

      for (int step = 0; step <= depthSteps; step++) {
        // u = 0 at horizon, 1 at bottom foreground
        final u = step / depthSteps;
        final depthCurve = math.pow(u, 1.85).toDouble();

        // Wave travels forward along depth axis
        final waveSamplePos = effectivePhase - (u * 1.5) + (trackOffset.abs() * 0.2);
        final ecgVal = _ecgWave(waveSamplePos);

        // Perspective 3D coordinates
        final xSpread = (w * 0.45) * depthCurve;
        final x = (w * 0.5) + (trackOffset * xSpread);
        final baseY = horizonY + (h - horizonY) * depthCurve;
        final amplitude = (45.0 * depthCurve) * (trackOffset == 0.0 ? 1.0 : 0.7);
        final y = baseY - (ecgVal * amplitude);

        if (!started) {
          path.moveTo(x, y);
          if (!isLowEnd) glowPath.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
          if (!isLowEnd) glowPath.lineTo(x, y);
        }
      }

      // Depth-scaled opacity (strictly clamped <= 8%)
      final isCenter = trackOffset == 0.0;
      final baseAlpha = (isCenter ? 0.06 : 0.035) * (isThinking ? 1.15 : 1.0);
      final strokeWidth = isCenter ? 1.8 : 1.1;

      // Glow pass (outer subtle halo, <= 3% opacity)
      if (!isLowEnd) {
        final glowPaint = Paint()
          ..color = const Color(0xFFC30121).withValues(alpha: (baseAlpha * 0.4).clamp(0.005, 0.03))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawPath(glowPath, glowPaint);
      }

      // Sharp core waveform line (<= 8% opacity)
      final coreColor = const Color(0xFFC30121).withValues(alpha: baseAlpha.clamp(0.01, 0.08));

      final linePaint = Paint()
        ..color = coreColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Ecg3DPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isThinking != isThinking ||
        oldDelegate.isLowEnd != isLowEnd;
  }
}

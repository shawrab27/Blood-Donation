// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable card widget that fills with a liquid wave animation from bottom to top on tap down.
///
/// Behavior:
/// - Default: Base background color (white), dark text/icons.
/// - On tap down: Blood-red liquid rises from the bottom of the card to the top with
///   two overlapping sine waves moving in opposite directions.
/// - Wave amplitude starts at ~8px and smoothly shrinks to 0px at 100% fill.
/// - Text and icons smoothly transition from dark to white via the builder's fill progress (0..1).
/// - On tap up: The fill completes to 100% before triggering [onTap].
/// - On tap cancel / drag away: The liquid smoothly drains back down to 0%.
class AnimatedFillCard extends StatefulWidget {
  final Widget Function(BuildContext context, double fillLevel)? builder;
  final Widget? child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color fillColor;
  final Color secondaryFillColor;
  final double amplitude;
  final List<BoxShadow>? boxShadow;
  final Duration fillDuration;
  final Duration waveDuration;
  final bool enabled;

  const AnimatedFillCard({
    super.key,
    this.builder,
    this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFF0E5E5),
    this.fillColor = const Color(0xFFB71C1C),
    this.secondaryFillColor = const Color(0xFFE53935),
    this.amplitude = 8.0,
    this.boxShadow,
    this.fillDuration = const Duration(milliseconds: 900),
    this.waveDuration = const Duration(seconds: 2),
    this.enabled = true,
  }) : assert(builder != null || child != null, 'Either builder or child must be provided');

  @override
  State<AnimatedFillCard> createState() => _AnimatedFillCardState();
}

class _AnimatedFillCardState extends State<AnimatedFillCard>
    with TickerProviderStateMixin {
  late final AnimationController _levelController;
  late final Animation<double> _levelAnimation;
  late final AnimationController _waveController;

  bool _isPressed = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    // 900ms easeInOut level controller
    _levelController = AnimationController(
      vsync: this,
      duration: widget.fillDuration,
    );
    _levelAnimation = CurvedAnimation(
      parent: _levelController,
      curve: Curves.easeInOut,
    );

    // 2s repeating wave controller (only runs while being pressed or filled)
    _waveController = AnimationController(
      vsync: this,
      duration: widget.waveDuration,
    );

    _levelController.addStatusListener(_onLevelStatusChanged);
  }

  void _onLevelStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Wave stops once completely filled (card is solid flat color at 100%)
      if (_waveController.isAnimating) {
        _waveController.stop();
      }
      if (_isCompleting) {
        _isCompleting = false;
        widget.onTap?.call();
        // Smoothly drain back after triggering action
        if (mounted) {
          _levelController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      }
    } else if (status == AnimationStatus.dismissed) {
      // Liquid has fully drained to 0: stop wave animation to eliminate CPU cycles
      if (!_isPressed && _waveController.isAnimating) {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _levelController.removeStatusListener(_onLevelStatusChanged);
    _levelController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _isPressed = true;
    _isCompleting = false;
    if (!_waveController.isAnimating) {
      _waveController.repeat();
    }
    _levelController.forward();
    if (mounted) setState(() {});
  }

  void _handleTapUp(TapUpDetails _) {
    _isPressed = false;
    if (_levelController.value >= 1.0) {
      // Already filled: trigger immediately
      widget.onTap?.call();
      _levelController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      // Let the fill finish first, then navigate
      _isCompleting = true;
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
      _levelController.forward();
    }
    if (mounted) setState(() {});
  }

  void _handleTapCancel() {
    // On drag away / cancel: liquid smoothly drains back down, colors revert
    _isPressed = false;
    _isCompleting = false;
    _levelController.reverse();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Micro-scale press response (0.97 over 120ms with Curves.easeOutCubic) per S2 rule
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? _handleTapDown : null,
        onTapUp: widget.enabled ? _handleTapUp : null,
        onTapCancel: widget.enabled ? _handleTapCancel : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: widget.boxShadow ??
                const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // Base white background layer
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: widget.borderColor, width: 1.2),
                    ),
                  ),
                ),

                // Liquid blood fill wave layer wrapped in RepaintBoundary for 60fps/120fps smoothness
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_levelAnimation, _waveController]),
                      builder: (context, _) {
                        final level = _levelAnimation.value;
                        if (level <= 0.0) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: LiquidFillPainter(
                            level: level,
                            wavePhase: _waveController.value * 2 * math.pi,
                            amplitude: widget.amplitude,
                            color: widget.fillColor,
                            secondaryColor: widget.secondaryFillColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Content layer with color transitions
                AnimatedBuilder(
                  animation: _levelAnimation,
                  builder: (context, _) {
                    final progress = _levelAnimation.value;
                    return widget.builder != null
                        ? widget.builder!(context, progress)
                        : (widget.child ?? const SizedBox.shrink());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering two overlapping sine waves that rise like liquid blood.
///
/// Features:
/// - Dark red (#B71C1C) front wave and lighter semi-transparent red (#E53935) back wave.
/// - Waves move horizontally in opposite directions continuously.
/// - Wave amplitude shrinks from [amplitude] (~8px) down to 0px at 100% fill level.
/// - Wave path is built in steps of 2px using `y = baseY + amplitude * sin((x / width * 2π) + phase)`.
class LiquidFillPainter extends CustomPainter {
  final double level;
  final double wavePhase;
  final double amplitude;
  final Color color;
  final Color secondaryColor;

  LiquidFillPainter({
    required this.level,
    required this.wavePhase,
    required this.amplitude,
    required this.color,
    this.secondaryColor = const Color(0xFFE53935),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0.0) return;

    // At 100% fill, render perfectly flat solid card
    if (level >= 1.0) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final baseY = size.height * (1.0 - level);

    // Amplitude smoothly shrinks to 0 at 100%, and softens near the very bottom (0%)
    final effectiveAmp = amplitude * (1.0 - level) * math.min(1.0, level * 6.0);

    // 1. Back/Lighter wave (#E53935 semi-transparent), moving horizontally in opposite direction
    final backPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    final backPath = Path();
    backPath.moveTo(0, size.height);
    final phase1 = -wavePhase + (math.pi / 2);
    final startY1 = baseY + effectiveAmp * math.sin(phase1);
    backPath.lineTo(0, startY1);

    for (double x = 0; x <= size.width; x += 2.0) {
      final y = baseY + effectiveAmp * math.sin((x / size.width * 2 * math.pi) + phase1);
      backPath.lineTo(x, y);
    }
    backPath.lineTo(size.width, size.height);
    backPath.close();
    canvas.drawPath(backPath, backPaint);

    // 2. Front wave (Dark blood red #B71C1C), moving in forward direction
    final frontPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final frontPath = Path();
    frontPath.moveTo(0, size.height);
    final phase2 = wavePhase;
    final startY2 = baseY + effectiveAmp * math.sin(phase2);
    frontPath.lineTo(0, startY2);

    for (double x = 0; x <= size.width; x += 2.0) {
      final y = baseY + effectiveAmp * math.sin((x / size.width * 2 * math.pi) + phase2);
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(size.width, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant LiquidFillPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

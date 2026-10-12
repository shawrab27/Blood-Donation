// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable vector BrandMark widget for splash, loader, app bar, and floating action button.
///
/// Features:
/// - Exact vector brand geometry (red ring, white background, red blood-drop)
/// - Only the inner heartbeat ECG line animates (~2.5s loop via PathMetric.extractPath)
/// - The entire outer button / drop remains completely still (zero bouncing or shaking)
/// - Wrapped in RepaintBoundary for optimal GPU layer caching
/// - Automatically disables animation when [MediaQuery.disableAnimations] is true
/// - Lifecycle-aware: stops animation when app is not resumed
class BrandMark extends StatefulWidget {
  final double size;
  final bool animateHeartbeat;
  final Color primaryColor;
  final Color backgroundColor;
  final Color heartbeatColor;
  final double strokeWidth;

  const BrandMark({
    super.key,
    this.size = 48,
    this.animateHeartbeat = true,
    this.primaryColor = const Color(0xFFC30121),
    this.backgroundColor = Colors.white,
    this.heartbeatColor = Colors.white,
    this.strokeWidth = 2.0,
  });

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    if (widget.animateHeartbeat) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant BrandMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateHeartbeat != oldWidget.animateHeartbeat) {
      if (widget.animateHeartbeat) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.animateHeartbeat && !_controller.isAnimating) {
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shouldAnimate = widget.animateHeartbeat && !disableAnimations;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: shouldAnimate
            ? AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _BrandMarkPainter(
                      progress: _controller.value,
                      primaryColor: widget.primaryColor,
                      backgroundColor: widget.backgroundColor,
                      heartbeatColor: widget.heartbeatColor,
                      strokeWidth: widget.strokeWidth,
                    ),
                  );
                },
              )
            : CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _BrandMarkPainter(
                  progress: 1.0,
                  primaryColor: widget.primaryColor,
                  backgroundColor: widget.backgroundColor,
                  heartbeatColor: widget.heartbeatColor,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color backgroundColor;
  final Color heartbeatColor;
  final double strokeWidth;

  _BrandMarkPainter({
    required this.progress,
    required this.primaryColor,
    required this.backgroundColor,
    required this.heartbeatColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = w < h ? w : h;
    final cx = w / 2;
    final cy = h / 2;
    final r = s / 2 - 1.5;

    // 1. Background Circle
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // 2. Primary Border Ring
    final ringPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.04).clamp(1.5, 3.5);
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    // 3. Blood Drop Path (Centered)
    final dropPath = Path();
    final dropTopY = cy - s * 0.32;
    final dropBottomY = cy + s * 0.26;
    final dropWidth = s * 0.40;

    dropPath.moveTo(cx, dropTopY);
    // Left curvature
    dropPath.cubicTo(
      cx - dropWidth * 0.85, cy - s * 0.05,
      cx - dropWidth * 0.85, dropBottomY,
      cx, dropBottomY,
    );
    // Right curvature
    dropPath.cubicTo(
      cx + dropWidth * 0.85, dropBottomY,
      cx + dropWidth * 0.85, cy - s * 0.05,
      cx, dropTopY,
    );
    dropPath.close();

    final dropPaint = Paint()..color = primaryColor;
    canvas.drawPath(dropPath, dropPaint);

    // 4. Inner Heartbeat ECG Waveform Path (drawn across center/lower part of drop)
    final ecgY = cy + s * 0.04;
    final ecgLeft = cx - s * 0.28;
    final ecgRight = cx + s * 0.28;
    final ecgSpan = ecgRight - ecgLeft;

    final ecgPath = Path();
    ecgPath.moveTo(ecgLeft, ecgY);
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.22, ecgY);
    // P-wave slight bump
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.30, ecgY - s * 0.04);
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.36, ecgY);
    // Q dip
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.42, ecgY + s * 0.05);
    // R peak (high spike)
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.50, ecgY - s * 0.22);
    // S dip (deep dip)
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.58, ecgY + s * 0.12);
    // T wave
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.65, ecgY);
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.75, ecgY - s * 0.06);
    ecgPath.lineTo(ecgLeft + ecgSpan * 0.82, ecgY);
    ecgPath.lineTo(ecgRight, ecgY);

    final metrics = ecgPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;

    // Animation: moving trace pulse with head and tail
    // Over a 2.5s loop:
    // 0.0 - 0.70: line draws from left to right with glowing leading head
    // 0.70 - 1.00: subtle pause / resting state
    final double activeT = (progress / 0.75).clamp(0.0, 1.0);
    final double tailT = ((progress - 0.20) / 0.75).clamp(0.0, 1.0);

    final double start = tailT * length;
    final double end = activeT * length;

    final linePaint = Paint()
      ..color = heartbeatColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s * 0.045).clamp(1.5, 3.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (end > start) {
      final extract = metric.extractPath(start, end);
      canvas.drawPath(extract, linePaint);
    } else {
      // Full resting path at lower opacity
      final dimPaint = Paint()
        ..color = heartbeatColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (s * 0.04).clamp(1.2, 2.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(ecgPath, dimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter old) {
    return old.progress != progress ||
        old.primaryColor != primaryColor ||
        old.backgroundColor != backgroundColor ||
        old.heartbeatColor != heartbeatColor;
  }
}

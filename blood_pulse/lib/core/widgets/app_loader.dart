// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:ui';
import 'package:flutter/material.dart';

enum AppLoaderSize {
  small(20, 2.0),
  medium(36, 2.8),
  large(56, 3.5);

  final double size;
  final double strokeWidth;
  const AppLoaderSize(this.size, this.strokeWidth);
}

/// HeartbeatLoader: an ECG line drawn with CustomPainter.
/// Replaces CircularProgressIndicator across the entire application.
/// - Path progress animated via PathMetric & AnimationController
/// - RepaintBoundary for optimal GPU caching
/// - Brand red Color(0xFFC30121)
/// - Sizes S / M / L
/// - Stops animation when TickerMode is off or app is paused
/// - Renders static icon when reduced-motion is requested
class AppLoader extends StatefulWidget {
  final AppLoaderSize size;
  final Color color;

  const AppLoader({
    super.key,
    this.size = AppLoaderSize.medium,
    this.color = const Color(0xFFC30121),
  });

  const AppLoader.small({
    super.key,
    this.color = const Color(0xFFC30121),
  }) : size = AppLoaderSize.small;

  const AppLoader.large({
    super.key,
    this.color = const Color(0xFFC30121),
  }) : size = AppLoaderSize.large;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return SizedBox(
        width: widget.size.size,
        height: widget.size.size,
        child: Icon(
          Icons.favorite_rounded,
          size: widget.size.size * 0.8,
          color: widget.color,
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size.size,
        height: widget.size.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _HeartbeatPainter(
                progress: _controller.value,
                color: widget.color,
                strokeWidth: widget.size.strokeWidth,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _HeartbeatPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    final path = Path()
      ..moveTo(0, cy)
      ..lineTo(w * 0.25, cy)
      ..lineTo(w * 0.35, cy - h * 0.2)
      ..lineTo(w * 0.45, cy + h * 0.25)
      ..lineTo(w * 0.55, cy - h * 0.45)
      ..lineTo(w * 0.65, cy + h * 0.3)
      ..lineTo(w * 0.75, cy)
      ..lineTo(w, cy);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;

    final double start = (progress - 0.35).clamp(0.0, 1.0) * length;
    final double end = progress * length;

    final extractPath = metric.extractPath(start, end);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

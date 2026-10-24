// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: Progress ring with ECG blip orbiting circumference, never overlapping text (C2/E5)
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RingEcgProgress extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Widget centerChild;

  const RingEcgProgress({
    super.key,
    required this.progress,
    this.size = 124,
    required this.centerChild,
  });

  @override
  State<RingEcgProgress> createState() => _RingEcgProgressState();
}

class _RingEcgProgressState extends State<RingEcgProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.stop();
    }

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track
            CircularProgressIndicator(
              value: widget.progress.clamp(0.0, 1.0),
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              backgroundColor: const Color(0xFFFFE8EA),
            ),
            // Orbiting ECG blip around the outer border
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _OrbitEcgPainter(
                  rotation: _ctrl.value * 2 * math.pi,
                  color: AppColors.primary,
                ),
              ),
            ),
            // Unobstructed center content
            Center(child: widget.centerChild),
          ],
        ),
      ),
    );
  }
}

class _OrbitEcgPainter extends CustomPainter {
  final double rotation;
  final Color color;

  _OrbitEcgPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3.5;

    final angle = rotation - (math.pi / 2);
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 5.5, glowPaint);
    canvas.drawCircle(Offset(x, y), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitEcgPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

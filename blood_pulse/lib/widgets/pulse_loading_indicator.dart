// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:math';
import 'package:flutter/material.dart';

class PulseLoadingIndicator extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  const PulseLoadingIndicator({
    super.key,
    this.width = 60.0,
    this.height = 36.0,
    this.color = const Color(0xFFC30121), // BloodPulse Primary Red
    this.backgroundColor = const Color(0xFFFDF3F3), // BloodPulse Surface Color
    this.strokeWidth = 2.5,
  });

  @override
  State<PulseLoadingIndicator> createState() => _PulseLoadingIndicatorState();
}

class _PulseLoadingIndicatorState extends State<PulseLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(50.0), // Full capsule/pill shape
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _PulsePainter(
              progress: _controller.value,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _PulsePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the faint background track
    final trackPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // Define the heartbeat (ECG) pulse path
    path.moveTo(0, midY);
    path.lineTo(w * 0.20, midY);          // Flat baseline start
    path.lineTo(w * 0.30, midY + h * 0.25); // Q (small dip)
    path.lineTo(w * 0.50, midY - h * 0.45); // R (high peak)
    path.lineTo(w * 0.65, midY + h * 0.35); // S (deep dip)
    path.lineTo(w * 0.75, midY);          // Return to baseline
    path.lineTo(w, midY);                 // Flat baseline end

    canvas.drawPath(path, trackPaint);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;

    // 2. Draw the active animated segment traveling along the path
    // The active segment is about 35% of the total path length
    final segmentLength = length * 0.35;
    
    // Calculate start and end distances based on the animation progress (0.0 to 1.0)
    // -segmentLength ensures it smoothly enters from the left edge
    final startDistance = -segmentLength + (length + segmentLength) * progress;
    final endDistance = startDistance + segmentLength;

    // Extract the portion of the path currently active
    final extractPath = metric.extractPath(
      max(0.0, startDistance),
      min(length, endDistance),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E1 EcgLoader (white ECG on red, built-in Flutter, RepaintBoundary)
import 'package:flutter/material.dart';
import '../theme/pulse_motion.dart';

class EcgLoader extends StatefulWidget {
  final Color color;
  final double width;
  final double height;
  final double strokeWidth;

  const EcgLoader({
    super.key,
    this.color = Colors.white,
    this.width = 48,
    this.height = 24,
    this.strokeWidth = 2.0,
  });

  @override
  State<EcgLoader> createState() => _EcgLoaderState();
}

class _EcgLoaderState extends State<EcgLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: PulseMotion.slow,
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
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _EcgLoaderPainter(
            progress: _ctrl.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _EcgLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _EcgLoaderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final w = size.width;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final blipX = (progress * (w + 40)) - 20;

    path.moveTo(0, centerY);
    path.lineTo(blipX - 12, centerY);
    path.lineTo(blipX - 8, centerY - 2);
    path.lineTo(blipX - 5, centerY);
    path.lineTo(blipX - 3, centerY + 2);
    path.lineTo(blipX - 1, centerY - (size.height * 0.45));
    path.lineTo(blipX + 1.5, centerY + (size.height * 0.35));
    path.lineTo(blipX + 4, centerY - 2.5);
    path.lineTo(blipX + 7, centerY);
    path.lineTo(w, centerY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: Shared single red baseline with 60dp traveling ECG pulse blip (D1/D17)
import 'package:flutter/material.dart';

class EcgTabIndicator extends StatelessWidget {
  final TabController controller;
  final int tabCount;
  final double height;
  final Color color;

  const EcgTabIndicator({
    super.key,
    required this.controller,
    required this.tabCount,
    this.height = 14.0,
    this.color = const Color(0xFFC30121),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final animVal = controller.animation?.value ?? controller.index.toDouble();
        return CustomPaint(
          size: Size(double.infinity, height),
          painter: _EcgLineAndBlipPainter(
            animationValue: animVal,
            tabCount: tabCount,
            color: color,
          ),
        );
      },
    );
  }
}

class _EcgLineAndBlipPainter extends CustomPainter {
  final double animationValue;
  final int tabCount;
  final Color color;

  _EcgLineAndBlipPainter({
    required this.animationValue,
    required this.tabCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tabCount <= 0) return;

    final baselineY = size.height - 2.0;

    // 1. Draw ONE continuous red baseline across the entire width
    final basePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), basePaint);

    // 2. Calculate center position of traveling ~60dp ECG blip
    final tabWidth = size.width / tabCount;
    final centerX = (animationValue * tabWidth) + (tabWidth / 2);

    // 3. Draw the ECG blip (~60dp width) with P-Q-R-S-T wave resting over the baseline
    final clearPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX - 24, baselineY), Offset(centerX + 24, baselineY), clearPaint);

    final blipPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(centerX - 26, baselineY);
    path.lineTo(centerX - 16, baselineY);
    // P wave
    path.lineTo(centerX - 12, baselineY - 2.5);
    path.lineTo(centerX - 8, baselineY);
    // Q dip
    path.lineTo(centerX - 5, baselineY + 2.0);
    // R spike
    path.lineTo(centerX - 1.5, baselineY - 8.5);
    // S dip
    path.lineTo(centerX + 2.0, baselineY + 3.5);
    // T wave
    path.lineTo(centerX + 6.0, baselineY - 3.0);
    path.lineTo(centerX + 10.0, baselineY);
    path.lineTo(centerX + 26, baselineY);

    canvas.drawPath(path, blipPaint);
  }

  @override
  bool shouldRepaint(covariant _EcgLineAndBlipPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.tabCount != tabCount ||
        oldDelegate.color != color;
  }
}

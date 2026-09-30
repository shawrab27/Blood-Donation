// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Accurate, official vector representation of the Google "G" logo
/// conforming to Google Brand Identity Guidelines.
///
/// Rendered using Skia/Impeller vector paths at 100% native resolution
/// with zero pixelation or raster scaling artifacts.
class GoogleLogo extends StatelessWidget {
  /// Dimension of the logo (width and height). Defaults to 24.
  final double size;

  const GoogleLogo({
    super.key,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google logo',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: const GoogleLogoPainter(),
        ),
      ),
    );
  }
}

/// CustomPainter rendering the authentic Google "G" four-color vector paths.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  // Official Google Brand Colors
  static const Color blue = Color(0xFF4285F4);
  static const Color green = Color(0xFF34A853);
  static const Color yellow = Color(0xFFFBBC05);
  static const Color red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinate system based on standard 118 x 120 viewBox
    const double baseWidth = 118.0;
    const double baseHeight = 120.0;

    final double scale = (size.width / baseWidth < size.height / baseHeight)
        ? size.width / baseWidth
        : size.height / baseHeight;

    final double dx = (size.width - baseWidth * scale) / 2.0;
    final double dy = (size.height - baseHeight * scale) / 2.0;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Blue (#4285F4)
    paint.color = blue;
    final Path bluePath = Path()
      ..moveTo(117.6, 61.3636364)
      ..cubicTo(117.6, 57.1090909, 117.218182, 53.0181818, 116.509091, 49.0909091)
      ..lineTo(60.0, 49.0909091)
      ..lineTo(60.0, 72.3)
      ..lineTo(92.2909091, 72.3)
      ..cubicTo(90.9, 79.8, 86.6727273, 86.1545455, 80.3181818, 90.4090909)
      ..lineTo(80.3181818, 105.463636)
      ..lineTo(99.7090909, 105.463636)
      ..cubicTo(111.054545, 95.0181818, 117.6, 79.6363636, 117.6, 61.3636364)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green (#34A853)
    paint.color = green;
    final Path greenPath = Path()
      ..moveTo(60.0, 120.0)
      ..cubicTo(76.2, 120.0, 89.7818182, 114.627273, 99.7090909, 105.463636)
      ..lineTo(80.3181818, 90.4090909)
      ..cubicTo(74.9454545, 94.0090909, 68.0727273, 96.1363636, 60.0, 96.1363636)
      ..cubicTo(44.3727273, 96.1363636, 31.1454545, 85.5818182, 26.4272727, 71.4)
      ..lineTo(6.38181818, 71.4)
      ..lineTo(6.38181818, 86.9454545)
      ..cubicTo(16.2545455, 106.554545, 36.5454545, 120.0, 60.0, 120.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow (#FBBC05)
    paint.color = yellow;
    final Path yellowPath = Path()
      ..moveTo(26.4272727, 71.4)
      ..cubicTo(25.2272727, 67.8, 24.5454545, 63.9545455, 24.5454545, 60.0)
      ..cubicTo(24.5454545, 56.0454545, 25.2272727, 52.2, 26.4272727, 48.6)
      ..lineTo(26.4272727, 33.0545455)
      ..lineTo(6.38181818, 33.0545455)
      ..cubicTo(2.31818182, 41.1545455, 0.0, 50.3181818, 0.0, 60.0)
      ..cubicTo(0.0, 69.6818182, 2.31818182, 78.8454545, 6.38181818, 86.9454545)
      ..lineTo(26.4272727, 71.4)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red (#EA4335)
    paint.color = red;
    final Path redPath = Path()
      ..moveTo(60.0, 23.8636364)
      ..cubicTo(68.8090909, 23.8636364, 76.7181818, 26.8909091, 82.9363636, 32.8363636)
      ..lineTo(100.145455, 15.6272727)
      ..cubicTo(89.7545455, 5.94545455, 76.1727273, 0.0, 60.0, 0.0)
      ..cubicTo(36.5454545, 0.0, 16.2545455, 13.4454545, 6.38181818, 33.0545455)
      ..lineTo(26.4272727, 48.6)
      ..cubicTo(31.1454545, 34.4181818, 44.3727273, 23.8636364, 60.0, 23.8636364)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

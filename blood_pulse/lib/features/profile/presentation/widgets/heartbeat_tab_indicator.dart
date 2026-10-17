// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Custom TabBar Indicator that draws a 3px red line with an ECG heartbeat spike.
/// 1:1 match to Stitch design specification:
/// Active indicator: heartbeat / ECG pulse line 3px thick #c30121 with center pulse spike.
/// Driven by TabController.animation without per-frame setState.
class HeartbeatTabIndicator extends Decoration {
  final Color color;
  final double strokeWidth;
  final double spikeHeight;
  final Animation<double>? animation;

  const HeartbeatTabIndicator({
    this.color = const Color(0xFFC30121),
    this.strokeWidth = 3.0,
    this.spikeHeight = 10.0,
    this.animation,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _HeartbeatBoxPainter(this, onChanged);
  }
}

class _HeartbeatBoxPainter extends BoxPainter {
  final HeartbeatTabIndicator decoration;

  _HeartbeatBoxPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);
    final size = configuration.size!;
    final width = size.width;
    final height = size.height;
    final baselineY = offset.dy + height - 2.0;
    final centerX = offset.dx + (width / 2);
    // Keep spike within safe 6px height so it never overlaps label text under varying text scale
    final effectiveSpikeHeight = decoration.spikeHeight.clamp(2.0, 6.5);

    final Paint paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = decoration.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    path.moveTo(offset.dx + 4, baselineY);
    path.lineTo(centerX - 14, baselineY);
    // P wave (slight up)
    path.lineTo(centerX - 10, baselineY - 1.5);
    path.lineTo(centerX - 7, baselineY);
    // Q dip (slight down)
    path.lineTo(centerX - 4, baselineY + 1.5);
    // R spike (high up, bounded)
    path.lineTo(centerX - 1.5, baselineY - effectiveSpikeHeight);
    // S dip (sharp down)
    path.lineTo(centerX + 1.5, baselineY + 2.5);
    // T wave (gentle recovery)
    path.lineTo(centerX + 5, baselineY - 2.0);
    path.lineTo(centerX + 8, baselineY);
    path.lineTo(offset.dx + width - 4, baselineY);

    canvas.drawPath(path, paint);
  }
}

/// Custom painter for inactive tab baseline
class TabBaselinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const TabBaselinePainter({
    this.color = const Color(0xFFFFEBEE),
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final y = size.height - 2.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Standalone ECG Heartbeat Painter driven directly by TabController.animation.
/// Zero per-frame setState calls.
class HeartbeatAnimationIndicatorPainter extends CustomPainter {
  final Animation<double> animation;
  final int tabCount;
  final Color color;
  final double strokeWidth;
  final double spikeHeight;

  HeartbeatAnimationIndicatorPainter({
    required this.animation,
    this.tabCount = 3,
    this.color = const Color(0xFFC30121),
    this.strokeWidth = 2.5,
    this.spikeHeight = 8.0,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (tabCount <= 0) return;
    final tabWidth = size.width / tabCount;
    final animVal = animation.value;
    final currentOffset = animVal * tabWidth;
    final baselineY = size.height - 2.0;
    final centerX = currentOffset + (tabWidth / 2);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    path.moveTo(currentOffset + 4, baselineY);
    path.lineTo(centerX - 16, baselineY);
    path.lineTo(centerX - 12, baselineY - 2);
    path.lineTo(centerX - 8, baselineY);
    path.lineTo(centerX - 5, baselineY + 2);
    path.lineTo(centerX - 2, baselineY - spikeHeight);
    path.lineTo(centerX + 2, baselineY + 4);
    path.lineTo(centerX + 6, baselineY - 3);
    path.lineTo(centerX + 10, baselineY);
    path.lineTo(currentOffset + tabWidth - 4, baselineY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HeartbeatAnimationIndicatorPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.tabCount != tabCount ||
        oldDelegate.color != color;
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// PulseAI FAB icon: red circular ring, white blood-drop, red ECG line.
///
/// Animation (1600ms loop):
///   0–300ms   flat baseline
///   300–500ms lub spike up/down
///   500–700ms dub spike up/down
///   700–1600ms flat rest (700ms rest as per spec)
///
/// Static when [MediaQuery.disableAnimations].
/// [asset] is accepted for API compatibility but NOT rendered — the PNG is kept.
class HeartbeatIcon extends StatefulWidget {
  final double size;
  // Keep asset param for API compat with pulseai_overlay.dart; file is preserved.
  final String asset;
  final bool animate;

  const HeartbeatIcon({
    super.key,
    required this.asset,
    this.size = 56,
    this.animate = true,
  });

  @override
  State<HeartbeatIcon> createState() => _HeartbeatIconState();
}

class _HeartbeatIconState extends State<HeartbeatIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.of(context).disableAnimations;
    if (!widget.animate || disabled) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _PulseAiFabPainter(_c.value),
          ),
        ),
      ),
    );
  }
}

/// Draws:
///   1. Red circular ring (border of the FAB circle)
///   2. White filled circle background
///   3. White blood-drop shape (centre)
///   4. Red ECG line animating across the icon bottom-half
class _PulseAiFabPainter extends CustomPainter {
  static const Color _red = Color(0xFFC30121);

  final double t; // 0..1 over the 1600ms period

  _PulseAiFabPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 2; // inset 2px for stroke

    // ── 1. Background circle (white) ──────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // ── 2. Red ring border ────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── 3. White blood-drop (centre, upper 55% of circle) ────────────────────
    _drawBloodDrop(canvas, Offset(cx, cy * 0.88), r * 0.32);

    // ── 4. Animated ECG line (lower 35% of circle) ───────────────────────────
    _drawEcgLine(canvas, size, t);
  }

  void _drawBloodDrop(Canvas canvas, Offset centre, double dropR) {
    // Blood-drop: circle bottom + pointed top
    final path = Path();
    // The "tip" is at top, the rounded base is below
    final tip = Offset(centre.dx, centre.dy - dropR * 1.6);
    final baseY = centre.dy + dropR * 0.6;

    path.moveTo(tip.dx, tip.dy);
    // Left arc from tip to base
    path.cubicTo(
      tip.dx - dropR * 0.8, centre.dy - dropR * 0.4,
      tip.dx - dropR, baseY - dropR * 0.2,
      tip.dx, baseY,
    );
    // Right arc from base to tip
    path.cubicTo(
      tip.dx + dropR, baseY - dropR * 0.2,
      tip.dx + dropR * 0.8, centre.dy - dropR * 0.4,
      tip.dx, tip.dy,
    );
    path.close();

    canvas.drawPath(path, Paint()..color = _red);
  }

  void _drawEcgLine(Canvas canvas, Size size, double t) {
    final cx = size.width / 2;
    final w = size.width;
    final lineY = size.height * 0.76; // baseline y
    final spikeH = size.height * 0.22; // spike height

    // ECG animation: scrolls the waveform left across the bottom strip.
    // The path is drawn in a [-w, 0] range then translated by phase.
    // Phase goes 0→1 over the animation period — wrapping.
    final phase = t * w; // pixels scrolled

    final paint = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Clip to inner circle
    final r = math.min(cx, size.height / 2) - 2;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, size.height / 2), radius: r)));

    // One ECG cycle width = w (the full icon width) over 1600ms
    // Pattern: flat 0.19, lub spike 0.125*w, flat 0.03, dub spike 0.10*w, flat rest
    // We draw two cycles so the scroll never shows a gap
    for (int cycle = -1; cycle <= 1; cycle++) {
      final ox = cycle * w - phase + cx; // origin x for this cycle
      _drawEcgCycle(canvas, ox, lineY, spikeH, w, paint);
    }

    canvas.restore();
  }

  void _drawEcgCycle(Canvas canvas, double ox, double lineY, double spikeH, double w, Paint paint) {
    // Segment widths (as fractions of cycle width w)
    final flatA = w * 0.19; // initial flat
    final lubW  = w * 0.12; // lub spike
    final midF  = w * 0.03; // flat between spikes
    final dubW  = w * 0.10; // dub spike
    // rest = remainder

    final path = Path();
    // Start
    path.moveTo(ox - w / 2, lineY);
    // flat A
    path.lineTo(ox - w / 2 + flatA, lineY);
    // lub: up, down, up (Q R S complex shape)
    final lubX = ox - w / 2 + flatA;
    path.lineTo(lubX + lubW * 0.15, lineY - spikeH * 0.25); // pre-spike
    path.lineTo(lubX + lubW * 0.30, lineY + spikeH * 0.15); // Q dip
    path.lineTo(lubX + lubW * 0.50, lineY - spikeH);         // R peak
    path.lineTo(lubX + lubW * 0.70, lineY + spikeH * 0.20);  // S dip
    path.lineTo(lubX + lubW, lineY);
    // mid flat
    path.lineTo(lubX + lubW + midF, lineY);
    // dub: smaller spike
    final dubX = lubX + lubW + midF;
    path.lineTo(dubX + dubW * 0.3, lineY - spikeH * 0.45);
    path.lineTo(dubX + dubW * 0.6, lineY - spikeH * 0.45);
    path.lineTo(dubX + dubW, lineY);
    // rest flat to end of cycle
    path.lineTo(ox + w / 2, lineY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PulseAiFabPainter old) => old.t != t;
}

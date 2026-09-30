import 'package:flutter/material.dart';

class HeartbeatIcon extends StatefulWidget {
  final double size;
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
  static const _red = Color(0xFFC30121);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)),
        weight: 9),
    TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 9),
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOut)),
        weight: 9),
    TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 11),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 62),
  ]).animate(_c);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || MediaQuery.of(context).disableAnimations) {
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
          builder: (_, __) {
            final glow = ((_scale.value - 1.0) / 0.22).clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: -s * 0.9,
                  top: -s * 0.9,
                  width: s * 2.8,
                  height: s * 2.8,
                  child: IgnorePointer(
                    child: CustomPaint(painter: _RipplePainter(_c.value, _red, s / 2)),
                  ),
                ),
                Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _red.withOpacity(0.15 + 0.40 * glow),
                          blurRadius: 8 + 18 * glow,
                          spreadRadius: 1 + 3 * glow,
                        ),
                      ],
                    ),
                    child: Image.asset(widget.asset, fit: BoxFit.contain),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t;
  final Color color;
  final double baseRadius;
  _RipplePainter(this.t, this.color, this.baseRadius);

  // [start, duration] as loop fractions: one ring per beat (lub, dub)
  static const List<List<double>> _rings = [
    [0.0, 0.50],
    [0.18, 0.50],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final r in _rings) {
      final p = (t - r[0]) / r[1];
      if (p < 0 || p > 1) continue;
      final eased = Curves.easeOut.transform(p);
      final radius = baseRadius * (1.0 + 0.9 * eased);
      final opacity = (1 - p) * 0.55;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - p) + 0.5,
      );
      canvas.drawCircle(center, radius, Paint()..color = color.withOpacity(opacity * 0.12));
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E3 Hero reveal (ECG line draws into logo once <=1.2s on LoginScreen)
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HeroRevealLogo extends StatefulWidget {
  final Widget child;

  const HeroRevealLogo({
    super.key,
    required this.child,
  });

  @override
  State<HeroRevealLogo> createState() => _HeroRevealLogoState();
}

class _HeroRevealLogoState extends State<HeroRevealLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _lineAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _lineAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );

    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Underlying ECG drawn line
          AnimatedBuilder(
            animation: _lineAnim,
            builder: (context, _) => CustomPaint(
              size: const Size(180, 48),
              painter: _HeroLinePainter(progress: _lineAnim.value),
            ),
          ),
          // Logo fading and stabilizing into view
          FadeTransition(
            opacity: _fadeAnim,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _HeroLinePainter extends CustomPainter {
  final double progress;

  _HeroLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final w = size.width;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, centerY);
    path.lineTo(w * 0.35, centerY);
    path.lineTo(w * 0.42, centerY - 14);
    path.lineTo(w * 0.50, centerY + 16);
    path.lineTo(w * 0.58, centerY - 6);
    path.lineTo(w * 0.65, centerY);
    path.lineTo(w, centerY);

    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final m = metrics.first;
      final extracted = m.extractPath(0.0, m.length * progress);
      canvas.drawPath(extracted, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

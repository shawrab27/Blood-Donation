// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E2 SuccessPulse (morph, ECG line draw, checkmark <=900ms, non-blocking)
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SuccessPulse extends StatefulWidget {
  final VoidCallback onComplete;
  final double height;
  final Color backgroundColor;

  const SuccessPulse({
    super.key,
    required this.onComplete,
    this.height = 48,
    this.backgroundColor = AppColors.success,
  });

  @override
  State<SuccessPulse> createState() => _SuccessPulseState();
}

class _SuccessPulseState extends State<SuccessPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ecgDrawAnim;
  late final Animation<double> _checkScaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _ecgDrawAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
    );

    _checkScaleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 1.0, curve: Curves.elasticOut),
    );

    _ctrl.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      widget.onComplete();
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(50),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final showCheck = _ctrl.value >= 0.55;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (!showCheck)
                  CustomPaint(
                    size: const Size(64, 24),
                    painter: _SuccessEcgDrawPainter(progress: _ecgDrawAnim.value),
                  ),
                if (showCheck)
                  Transform.scale(
                    scale: _checkScaleAnim.value,
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SuccessEcgDrawPainter extends CustomPainter {
  final double progress;

  _SuccessEcgDrawPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final w = size.width;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, centerY);
    path.lineTo(w * 0.3, centerY);
    path.lineTo(w * 0.4, centerY - (size.height * 0.4));
    path.lineTo(w * 0.5, centerY + (size.height * 0.4));
    path.lineTo(w * 0.6, centerY - (size.height * 0.2));
    path.lineTo(w * 0.7, centerY);
    path.lineTo(w, centerY);

    // Animate path draw
    final pMetrics = path.computeMetrics().toList();
    if (pMetrics.isNotEmpty) {
      final metric = pMetrics.first;
      final extract = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extract, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessEcgDrawPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

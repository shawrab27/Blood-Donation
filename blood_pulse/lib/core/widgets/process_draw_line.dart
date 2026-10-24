// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E5 ProcessDraw (timeline connector draws between steps as status advances)
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/pulse_motion.dart';

class ProcessDrawLine extends StatefulWidget {
  final bool isCompleted;
  final double height;
  final Color activeColor;
  final Color inactiveColor;

  const ProcessDrawLine({
    super.key,
    required this.isCompleted,
    this.height = 36.0,
    this.activeColor = AppColors.success,
    this.inactiveColor = const Color(0xFFE0E0E0),
  });

  @override
  State<ProcessDrawLine> createState() => _ProcessDrawLineState();
}

class _ProcessDrawLineState extends State<ProcessDrawLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: PulseMotion.slow,
    );

    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);

    if (widget.isCompleted) {
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ProcessDrawLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted && !oldWidget.isCompleted) {
      _ctrl.forward();
    } else if (!widget.isCompleted && oldWidget.isCompleted) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Container(
        width: 2.5,
        height: widget.height,
        color: widget.isCompleted ? widget.activeColor : widget.inactiveColor,
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: 2.5,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => CustomPaint(
            painter: _ProcessLinePainter(
              progress: _anim.value,
              activeColor: widget.activeColor,
              inactiveColor: widget.inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessLinePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _ProcessLinePainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = size.width
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), inactivePaint);

    if (progress > 0) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height * progress),
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProcessLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

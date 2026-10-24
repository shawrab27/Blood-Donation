// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E7 PingRipple (ECG ring ripple 2 repeats on in-app emergency banner)
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PingRipple extends StatefulWidget {
  final Widget child;
  final Color rippleColor;

  const PingRipple({
    super.key,
    required this.child,
    this.rippleColor = AppColors.primary,
  });

  @override
  State<PingRipple> createState() => _PingRippleState();
}

class _PingRippleState extends State<PingRipple> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _repeatsLeft = 2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _repeatsLeft--;
        if (_repeatsLeft > 0) {
          _ctrl.reset();
          _ctrl.forward();
        }
      }
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations || _repeatsLeft <= 0) {
      return widget.child;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final scale = 1.0 + (_ctrl.value * 0.18);
          final opacity = (1.0 - _ctrl.value).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_ctrl.isAnimating)
                Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity * 0.45,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: widget.rippleColor, width: 2.5),
                      ),
                    ),
                  ),
                ),
              widget.child,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

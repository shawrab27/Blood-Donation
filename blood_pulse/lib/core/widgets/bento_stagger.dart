// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E6 BentoStagger (40ms stagger, 300ms each, easeOutCubic)
import 'package:flutter/material.dart';
import '../theme/pulse_motion.dart';

class BentoStagger extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration staggerDelay;
  final Duration itemDuration;

  const BentoStagger({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 40),
    this.itemDuration = PulseMotion.normal, // 300ms
  });

  @override
  State<BentoStagger> createState() => _BentoStaggerState();
}

class _BentoStaggerState extends State<BentoStagger> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.itemDuration,
    );

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final totalDelay = widget.staggerDelay * widget.index;
    Future.delayed(totalDelay, () {
      if (mounted) {
        _ctrl.forward();
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
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

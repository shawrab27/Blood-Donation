// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

// USER RULE - do not change: E4 CountUp (600ms easeOut once per screen entry, Profile stats, Top Donors, Hydration)
import 'package:flutter/material.dart';
import '../theme/pulse_motion.dart';

class CountUpText extends StatefulWidget {
  final int endValue;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.endValue,
    this.style,
    this.suffix = '',
    this.duration = PulseMotion.slow, // 600ms
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<int> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _anim = IntTween(begin: 0, end: widget.endValue).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endValue != widget.endValue) {
      _ctrl.reset();
      _ctrl.forward();
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
      return Text('${widget.endValue}${widget.suffix}', style: widget.style);
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Text(
        '${_anim.value}${widget.suffix}',
        style: widget.style,
      ),
    );
  }
}

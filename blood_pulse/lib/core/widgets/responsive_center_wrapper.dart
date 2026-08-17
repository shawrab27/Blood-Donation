import 'package:flutter/material.dart';

/// Wraps content in a horizontally centered container with a maximum width.
/// 
/// This prevents screens (like forms, lists, or feeds) from stretching 
/// uncomfortably wide on ultra-wide desktop monitors or Web browsers.
/// It aligns content to the top so scrolling lists aren't vertically centered
/// when they contain few items.
class ResponsiveCenterWrapper extends StatelessWidget {
  const ResponsiveCenterWrapper({
    super.key,
    required this.child,
    this.maxWidth = 900.0,
  });

  /// The widget to constrain.
  final Widget child;

  /// The maximum width the [child] is allowed to occupy.
  /// 
  /// Suggested values:
  /// - `900.0` for single-column content (forms, standard lists).
  /// - `1200.0` for multi-column content (grids).
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

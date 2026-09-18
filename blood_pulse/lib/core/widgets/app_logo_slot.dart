import 'package:flutter/material.dart';
import 'app_logo.dart';

/// Standard logo size definitions for strict uniform scaling across categories.
abstract final class AppLogoSize {
  /// Standard fixed size for Splash screen hero logo.
  static const double splash = 120.0;

  /// Standard fixed size for Auth form cards (Login, OTP).
  static const double card = 56.0;

  /// Standard fixed size for top App Bars across all sub-pages and main tabs.
  static const double header = 38.0;
}

/// Centralized wrapper for the BloodPulse logo mark.
/// Delegates directly to [BloodPulseMark] for uniform rendering.
class AppLogoSlot extends StatelessWidget {
  const AppLogoSlot({
    super.key,
    this.size = AppLogoSize.header,
    this.backgroundColor,
    this.showShadow = false,
  });

  final double size;
  final Color? backgroundColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return BloodPulseMark(
      size: size,
      backgroundColor: backgroundColor,
      showShadow: showShadow,
    );
  }
}

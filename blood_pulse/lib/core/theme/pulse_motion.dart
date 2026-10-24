// USER RULE - do not change: S5 PulseMotion constants (fast 120ms, normal 300ms, slow 600ms), standard curves, and reduced-motion compliance
import 'package:flutter/material.dart';

/// Universal S5 Motion and Animation System for BloodPulse.
///
/// Defines standard design-system durations, easing curves, and utilities
/// to respect user preferences (e.g. `MediaQuery.disableAnimations`).
class PulseMotion {
  PulseMotion._();

  /// Fast transition (120ms) — used for tap scales, micro-feedback, and button presses.
  static const Duration fast = Duration(milliseconds: 120);

  /// Normal transition (300ms) — used for dialogs, bottom sheets, fades, tab blips.
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow transition (600ms) — used for hero reveals, loaders, count-ups, and complex drawings.
  static const Duration slow = Duration(milliseconds: 600);

  /// Standard default easing curve
  static const Curve curveDefault = Curves.easeOutCubic;

  /// Bounce curve for delightful confirmations and micro-pops
  static const Curve curveBounce = Curves.easeOutBack;

  /// Smooth ease-in-out for continuous looping or morphing animations
  static const Curve curveSmooth = Curves.easeInOutCubic;

  /// Sharp exit curve
  static const Curve curveSharp = Curves.easeOut;

  /// Returns [standard] duration, or [Duration.zero] if the device or user
  /// has requested animations to be disabled.
  static Duration duration(BuildContext context, Duration standard) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Duration.zero;
    }
    return standard;
  }
}

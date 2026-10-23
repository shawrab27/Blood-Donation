// USER RULE - do not change: S1 PrimaryButton label never clips or wraps at 320dp/360dp with textScale 1.3, arrow AFTER text, press-zoom, loading shows ONLY white ECG loader on red
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'capsule_button.dart';

/// Universal S1 Primary Button for BloodPulse.
///
/// Guaranteed specifications:
///   • Min-height 48dp, full capsule border radius (50)
///   • Label never clips or wraps at 320dp or 360dp width and textScale 1.3 (FittedBox + Flexible)
///   • Arrow icon strictly positioned AFTER label text
///   • Press-zoom animation (scale 0.97 over 120ms)
///   • Loading state shows ONLY the tapped button active with white ECG loader on red
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool isOutlined;
  final bool isLoading;
  final bool showGlow;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.leading,
    this.isOutlined = false,
    this.isLoading = false,
    this.showGlow = false,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return CapsuleButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      leading: leading,
      isOutlined: isOutlined,
      isLoading: isLoading,
      showGlow: showGlow,
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? AppColors.onPrimary,
      width: width,
      height: height < 48.0 ? 48.0 : height,
    );
  }
}

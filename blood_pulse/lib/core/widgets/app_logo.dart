import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Path to the official transparent PNG logo.
const String kBloodPulseIconAsset = 'assets/images/blood_pulse_icon.png';
const String kBloodPulseLogoAsset = 'assets/images/blood_pulse_logo.png';

/// The official BloodPulse mark widget.
///
/// Loads the official transparent PNG logo icon asset [kBloodPulseIconAsset]
/// featuring Deep Burgundy (#641C2D) and Primary Red (#C30121) branding.
/// Maintains a 100% transparent background with zero background box artifacts.
class BloodPulseMark extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color primaryColor;
  final Color secondaryColor;
  final bool showShadow;
  final String assetPath;

  const BloodPulseMark({
    super.key,
    this.size = 32.0,
    this.backgroundColor,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = AppColors.burgundy,
    this.showShadow = false,
    this.assetPath = kBloodPulseIconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        kBloodPulseLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? secondaryColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.favorite_rounded,
              color: primaryColor,
              size: size * 0.62,
            ),
          ),
        ),
      ),
    );

    if (backgroundColor == null && !showShadow) {
      return image;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(child: image),
    );
  }
}

/// Centralized, reusable branding logo widget for BloodPulse.
///
/// Pairs the official transparent PNG logo icon ([kBloodPulseIconAsset])
/// cleanly with the typography:
///   • "Blood" in Deep Burgundy (#641C2D)
///   • "Pulse" in Primary Red (#C30121)
///
/// Features:
///   • 100% transparent background, zero white/black box artifacts
///   • High contrast against light / blush pink top bars (#FDF3F3 / #FFF8F7)
///   • Optional subtitle badge for section/tab headers
///   • Scalable sizing with factory constructors: [.appBar], [.hero], [.card]
///   • Bulletproof error fallback ensuring zero crashes
class BloodPulseLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxFit fit;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double iconSize;
  final double fontSize;
  final bool showText;
  final bool showIcon;
  final double spacing;
  final Color primaryColor;
  final Color secondaryColor;
  final Axis direction;
  final String assetPath;

  const BloodPulseLogo({
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.subtitle,
    this.onTap,
    this.backgroundColor,
    this.iconSize = 32.0,
    this.fontSize = 20.0,
    this.showText = true,
    this.showIcon = true,
    this.spacing = 8.0,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = AppColors.burgundy,
    this.direction = Axis.horizontal,
    this.assetPath = kBloodPulseIconAsset,
  });

  /// Factory constructor for hero / splash screen branding.
  const BloodPulseLogo.hero({
    super.key,
    this.height = 110.0,
    this.width,
    this.fit = BoxFit.contain,
    this.subtitle,
    this.onTap,
    this.backgroundColor,
    this.iconSize = 88.0,
    this.fontSize = 36.0,
    this.showText = true,
    this.showIcon = true,
    this.spacing = 16.0,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = AppColors.burgundy,
    this.direction = Axis.vertical,
    this.assetPath = kBloodPulseIconAsset,
  });

  /// Factory constructor for compact AppBar layouts across all screens.
  const BloodPulseLogo.appBar({
    super.key,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.subtitle,
    this.onTap,
    this.backgroundColor,
    this.iconSize = 32.0,
    this.fontSize = 20.0,
    this.showText = true,
    this.showIcon = true,
    this.spacing = 8.0,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = AppColors.burgundy,
    this.direction = Axis.horizontal,
    this.assetPath = kBloodPulseIconAsset,
  });

  /// Factory constructor for card and modal dialog headers.
  const BloodPulseLogo.card({
    super.key,
    this.height = 56.0,
    this.width,
    this.fit = BoxFit.contain,
    this.subtitle,
    this.onTap,
    this.backgroundColor,
    this.iconSize = 48.0,
    this.fontSize = 24.0,
    this.showText = true,
    this.showIcon = true,
    this.spacing = 10.0,
    this.primaryColor = AppColors.primary,
    this.secondaryColor = AppColors.burgundy,
    this.direction = Axis.vertical,
    this.assetPath = kBloodPulseIconAsset,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = height ?? iconSize;

    final iconWidget = Image.asset(
      assetPath,
      height: effectiveIconSize,
      width: width ?? effectiveIconSize,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        kBloodPulseLogoAsset,
        height: effectiveIconSize,
        fit: fit,
        errorBuilder: (_, _, _) => _buildFallbackIcon(effectiveIconSize),
      ),
    );

    final textWidget = RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        children: [
          TextSpan(
            text: 'Blood',
            style: TextStyle(color: secondaryColor),
          ),
          TextSpan(
            text: 'Pulse',
            style: TextStyle(color: primaryColor),
          ),
        ],
      ),
    );

    Widget content;
    if (direction == Axis.horizontal) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            iconWidget,
            SizedBox(width: spacing),
          ],
          if (showText) textWidget,
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(maxWidth: 90),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            iconWidget,
            SizedBox(height: spacing),
          ],
          if (showText) textWidget,
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }

  Widget _buildFallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: secondaryColor.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: primaryColor,
          size: size * 0.62,
        ),
      ),
    );
  }
}

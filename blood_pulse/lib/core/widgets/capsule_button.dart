import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A pill-shaped (full-capsule) button matching the BloodPulse brand identity.
///
/// Features:
///   • Tap-scale animation (scale down to 0.96 on press, bounce back on release)
///   • Optional red glow shadow (`showGlow: true`)
///   • Supports primary (filled) and outlined variants
///   • `isLoading` state shows a circular progress indicator
///   • Strictly null-safe with `const` constructor support
///
/// Example:
/// ```dart
/// CapsuleButton(
///   label: 'Donate Blood',
///   onPressed: () {},
///   showGlow: true,
/// )
/// ```
class CapsuleButton extends StatefulWidget {
  const CapsuleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isOutlined = false,
    this.isLoading = false,
    this.showGlow = false,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 56,
  });

  /// Button label text.
  final String label;

  /// Called when the button is tapped. If null, the button is disabled.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// When true, renders an outlined (ghost) variant.
  final bool isOutlined;

  /// When true, replaces label+icon with a [CircularProgressIndicator].
  final bool isLoading;

  /// When true, adds a red glow box-shadow beneath the button.
  final bool showGlow;

  /// Override background colour (defaults to [AppColors.primary]).
  final Color? backgroundColor;

  /// Override foreground/text colour (defaults to [AppColors.onPrimary]).
  final Color? foregroundColor;

  /// Fixed width; defaults to `double.infinity` (full width).
  final double? width;

  /// Button height. Defaults to 56.
  final double height;

  @override
  State<CapsuleButton> createState() => _CapsuleButtonState();
}

class _CapsuleButtonState extends State<CapsuleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
  );

  void _onTapDown(TapDownDetails _) => _controller.reverse();
  void _onTapUp(TapUpDetails _) => _controller.forward();
  void _onTapCancel() => _controller.forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.isLoading;
    final Color bg = widget.backgroundColor ?? AppColors.primary;
    final Color fg = widget.foregroundColor ?? AppColors.onPrimary;

    Widget child;
    if (widget.isLoading) {
      child = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: fg,
            ),
          ),
        ],
      );
    }

    // ── Glow box shadow ──
    final List<BoxShadow> glowShadows = widget.showGlow && !disabled
        ? [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.primaryGlowSoft,
              blurRadius: 40,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
          ]
        : [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double? effectiveWidth =
            widget.width ?? (constraints.hasBoundedWidth ? double.infinity : null);

        return GestureDetector(
          onTapDown: disabled ? null : _onTapDown,
          onTapUp: disabled ? null : _onTapUp,
          onTapCancel: disabled ? null : _onTapCancel,
          onTap: disabled ? null : widget.onPressed,
          child: ScaleTransition(
            scale: _controller,
            child: Container(
              width: effectiveWidth,
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kCapsuleRadius),
                boxShadow: glowShadows,
                // Outlined variant — transparent fill
                color: widget.isOutlined
                    ? Colors.transparent
                    : (disabled ? Colors.grey.shade400 : bg),
                border: widget.isOutlined
                    ? Border.all(
                        color: disabled ? Colors.grey.shade400 : bg,
                        width: 1.5,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

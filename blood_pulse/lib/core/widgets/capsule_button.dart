import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

// USER RULE - do not change: S1 PrimaryButton / CapsuleButton label never clips or wraps at 320dp/360dp with textScale 1.3, arrow AFTER text, press-zoom, loading shows ONLY white ECG loader on red
class CapsuleButton extends StatefulWidget {
  const CapsuleButton({
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

  /// Button label text.
  final String label;

  /// Called when the button is tapped. If null, the button is disabled.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional custom leading widget (takes priority over [icon]).
  final Widget? leading;

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
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.97,
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
    // USER RULE - do not change: button stays red during loading; other buttons use IgnorePointer
    final bool disabled = widget.onPressed == null && !widget.isLoading;
    final Color bg = widget.isLoading ? AppColors.primary : (widget.backgroundColor ?? AppColors.primary);
    final Color fg = widget.foregroundColor ?? AppColors.onPrimary;

    Widget child;
    if (widget.isLoading) {
      // USER RULE - do not change: ONE shared animated white ECG-heartbeat loader
      child = const SizedBox(
        width: 32,
        height: 24,
        child: AppLoader(
          size: AppLoaderSize.small,
          color: Colors.white,
        ),
      );
    } else {
      final bool isArrow = widget.icon != null && (
        widget.icon == Icons.arrow_forward ||
        widget.icon == Icons.arrow_forward_rounded ||
        widget.icon == Icons.arrow_right_alt_rounded ||
        widget.icon == Icons.arrow_forward_ios_rounded
      );

      // USER RULE - do not change: arrow icon inside capsule buttons must come AFTER the label
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 10),
          ] else if (widget.icon != null && !isArrow) ...[
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: fg,
                ),
              ),
            ),
          ),
          if (isArrow) ...[
            const SizedBox(width: 8),
            Icon(widget.icon, size: 20, color: fg),
          ],
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
              height: widget.height < 48.0 ? 48.0 : widget.height,
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

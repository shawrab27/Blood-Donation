// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Central Design Tokens for Spacing and Dimensions across BloodPulse.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppSizes {
  AppSizes._();

  static const double minTouchTarget = 48.0;
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  static const double cardRadius = 20.0;
  static const double pillRadius = 50.0;
  static const double fabSize = 56.0;
  static const double fabBottomClearance = 88.0;
}

/// A button conforming to the 48dp minimum touch target rule, with text ellipsis / FittedBox.
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor = const Color(0xFFC30121),
    this.foregroundColor = Colors.white,
    this.height = AppSizes.buttonHeight,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: AppSizes.minTouchTarget,
        minWidth: AppSizes.minTouchTarget,
      ),
      child: SizedBox(
        height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.pillRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          onPressed: isLoading ? null : onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: foregroundColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ResponsiveRow: Renders as Row when screen is wide enough,
/// falls back to Column / Wrap when horizontal space is constrained (< 340dp).
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 340.0,
    this.mainAxisAlignment = MainAxisAlignment.spaceBetween,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }
        return Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        );
      },
    );
  }
}

/// StickyBottomBar: Sticky bottom action bar with SafeArea and dynamic padding,
/// guaranteeing buttons never get clipped or covered.
class StickyBottomBar extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double extraBottomPadding;

  const StickyBottomBar({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.extraBottomPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + safeBottom + bottomInset + extraBottomPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// FabInsets: Ensures screens reserve bottom clearance for floating actions (e.g. PulseAI FAB),
/// preventing overlap with primary content or buttons.
class FabInsets {
  FabInsets._();

  static const double fabHeight = 56.0;
  static const double fabSpacing = 16.0;
  static const double totalClearance = fabHeight + fabSpacing + 16.0; // 88.0

  /// Returns padding to append at the bottom of scroll views so FAB doesn't obscure content.
  static EdgeInsets bottomPadding([double extra = 0.0]) =>
      EdgeInsets.only(bottom: totalClearance + extra);

  /// Widget that inserts a spacer with fab clearance height.
  static Widget spacer([double extra = 0.0]) =>
      SizedBox(height: totalClearance + extra);
}

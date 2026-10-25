// USER RULE - do not change: S2 PressableScale scale 0.97 over 120ms for all tappable cards/boxes/buttons
import 'package:flutter/material.dart';

/// Universal S2 PressableScale widget for BloodPulse.
///
/// Smoothly scales down to 0.97 over 120ms with easeOutCubic on press,
/// returning to 1.0 on release or cancel.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;
  final bool enabled;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent _) {
    if (widget.enabled && !_isPressed) {
      setState(() => _isPressed = true);
    }
  }

  void _onPointerUp(PointerUpEvent _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaleWidget = AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) {
          if (widget.enabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.enabled ? widget.onTap : null,
        child: scaleWidget,
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: scaleWidget,
    );
  }
}

/// Shared button wrapper so all button types (Elevated, Outlined, Text, Icon)
/// and custom tappable buttons inherit the 0.97 scale over 120ms press-pop feedback.
class PressableButton extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const PressableButton({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// Wraps an ElevatedButton with 0.97 press-pop scale.
  static Widget elevated({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    required Widget child,
  }) {
    return PressableScale(
      enabled: onPressed != null,
      child: ElevatedButton(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        child: child,
      ),
    );
  }

  /// Wraps an OutlinedButton with 0.97 press-pop scale.
  static Widget outlined({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    required Widget child,
  }) {
    return PressableScale(
      enabled: onPressed != null,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        child: child,
      ),
    );
  }

  /// Wraps a TextButton with 0.97 press-pop scale.
  static Widget text({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    required Widget child,
  }) {
    return PressableScale(
      enabled: onPressed != null,
      child: TextButton(
        key: key,
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        focusNode: focusNode,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        child: child,
      ),
    );
  }

  /// Wraps an IconButton with 0.97 press-pop scale.
  static Widget icon({
    Key? key,
    double? iconSize,
    VisualDensity? visualDensity,
    EdgeInsetsGeometry? padding,
    AlignmentGeometry? alignment,
    double? splashRadius,
    Color? color,
    Color? focusColor,
    Color? hoverColor,
    Color? highlightColor,
    Color? splashColor,
    Color? disabledColor,
    required VoidCallback? onPressed,
    MouseCursor? mouseCursor,
    FocusNode? focusNode,
    bool autofocus = false,
    String? tooltip,
    bool? enableFeedback,
    BoxConstraints? constraints,
    ButtonStyle? style,
    bool? isSelected,
    Widget? selectedIcon,
    required Widget icon,
  }) {
    return PressableScale(
      enabled: onPressed != null,
      child: IconButton(
        key: key,
        iconSize: iconSize,
        visualDensity: visualDensity,
        padding: padding,
        alignment: alignment,
        splashRadius: splashRadius,
        color: color,
        focusColor: focusColor,
        hoverColor: hoverColor,
        highlightColor: highlightColor,
        splashColor: splashColor,
        disabledColor: disabledColor,
        onPressed: onPressed,
        mouseCursor: mouseCursor,
        focusNode: focusNode,
        autofocus: autofocus,
        tooltip: tooltip,
        enableFeedback: enableFeedback,
        constraints: constraints,
        style: style,
        isSelected: isSelected,
        selectedIcon: selectedIcon,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: enabled,
      child: child,
    );
  }
}

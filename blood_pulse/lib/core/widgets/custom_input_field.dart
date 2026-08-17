import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A full-capsule (pill-shape) text input field matching the BloodPulse design system.
///
/// Features:
///   • Full-capsule shape: [BorderRadius.circular(kCapsuleRadius)]
///   • Focus ring in brand red: [AppColors.primary] (#C30121)
///   • Optional leading prefix icon
///   • Optional trailing suffix widget (e.g., password toggle, clear button)
///   • Inline error message display
///   • Password obscure toggle built-in when [isPassword] is true
///
/// Example:
/// ```dart
/// CustomInputField(
///   label: 'Phone Number',
///   hint: 'e.g. 017XXXXXXXX',
///   prefixIcon: Icons.phone_outlined,
///   controller: _phoneCtrl,
///   validator: (v) => v!.isEmpty ? 'Required' : null,
/// )
/// ```
class CustomInputField extends StatefulWidget {
  const CustomInputField({
    super.key,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixWidget,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.isPassword = false,
    this.enabled = true,
    this.maxLines = 1,
    this.initialValue,
  });

  /// Optional floating label shown above the field.
  final String? label;

  /// Hint text shown inside the field.
  final String? hint;

  /// Leading icon inside the pill.
  final IconData? prefixIcon;

  /// Optional trailing widget (e.g., suffix icon button). Overridden by built-in
  /// password toggle when [isPassword] is true.
  final Widget? suffixWidget;

  /// External [TextEditingController].
  final TextEditingController? controller;

  /// Validation callback compatible with [Form].
  final String? Function(String?)? validator;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  /// When true, text is obscured and a show/hide toggle appears.
  final bool isPassword;

  final bool enabled;

  /// Max lines (defaults to 1 → single-line capsule).
  final int maxLines;

  /// Initial value when no [controller] is provided.
  final String? initialValue;

  @override
  State<CustomInputField> createState() => _CustomInputFieldState();
}

class _CustomInputFieldState extends State<CustomInputField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final bool effectiveObscure = widget.isPassword && _obscured;

    Widget? suffixIcon;
    if (widget.isPassword) {
      suffixIcon = IconButton(
        icon: Icon(
          _obscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
          color: AppColors.neutral,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    } else if (widget.suffixWidget != null) {
      suffixIcon = widget.suffixWidget;
    }

    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: effectiveObscure,
      enabled: widget.enabled,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textLight,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(
                widget.prefixIcon,
                size: 20,
                color: AppColors.neutral,
              )
            : null,
        suffixIcon: suffixIcon,
        // Borders are inherited from the global InputDecorationTheme
        // (all set to BorderRadius.circular(kCapsuleRadius)) — but we
        // explicitly re-specify here to guarantee correctness even when this
        // widget is used outside a MaterialApp with AppTheme applied.
        filled: true,
        fillColor: widget.enabled ? AppColors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kCapsuleRadius),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

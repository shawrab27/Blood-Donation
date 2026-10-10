// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';

/// Aspect ratio presets for poster export.
enum PosterAspectRatio {
  /// Square 1:1 — ideal for Instagram feed, Facebook.
  square,

  /// Portrait 4:5 — ideal for Instagram portrait posts.
  portrait,

  /// Vertical story 9:16 — ideal for Instagram/WhatsApp Stories, Reels.
  story,
}

extension PosterAspectRatioX on PosterAspectRatio {
  String get label {
    switch (this) {
      case PosterAspectRatio.square:
        return '1:1';
      case PosterAspectRatio.portrait:
        return '4:5';
      case PosterAspectRatio.story:
        return '9:16';
    }
  }

  String get description {
    switch (this) {
      case PosterAspectRatio.square:
        return 'Feed';
      case PosterAspectRatio.portrait:
        return 'Post';
      case PosterAspectRatio.story:
        return 'Story';
    }
  }

  double get ratio {
    switch (this) {
      case PosterAspectRatio.square:
        return 1.0;
      case PosterAspectRatio.portrait:
        return 4.0 / 5.0;
      case PosterAspectRatio.story:
        return 9.0 / 16.0;
    }
  }
}

/// Color theme preset for poster design.
enum PosterColorTheme {
  /// Crimson/White — BloodPulse brand default.
  crimson,

  /// Dark red/Black — high-contrast dark variant.
  darkRed,

  /// Pure black/White — minimal dark poster.
  midnight,

  /// White/Soft pink — light clinical poster.
  light,
}

extension PosterColorThemeX on PosterColorTheme {
  String get label {
    switch (this) {
      case PosterColorTheme.crimson:
        return 'Crimson';
      case PosterColorTheme.darkRed:
        return 'Dark Red';
      case PosterColorTheme.midnight:
        return 'Midnight';
      case PosterColorTheme.light:
        return 'Light';
    }
  }

  Color get primaryColor {
    switch (this) {
      case PosterColorTheme.crimson:
        return const Color(0xFFC30121);
      case PosterColorTheme.darkRed:
        return const Color(0xFF8B0000);
      case PosterColorTheme.midnight:
        return const Color(0xFF1A1A2E);
      case PosterColorTheme.light:
        return const Color(0xFFEF5350);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PosterColorTheme.crimson:
        return Colors.white;
      case PosterColorTheme.darkRed:
        return const Color(0xFF1A0005);
      case PosterColorTheme.midnight:
        return const Color(0xFF0D0D1A);
      case PosterColorTheme.light:
        return const Color(0xFFFFF8F7);
    }
  }

  Color get textColor {
    switch (this) {
      case PosterColorTheme.crimson:
        return const Color(0xFF2B2B2B);
      case PosterColorTheme.darkRed:
        return Colors.white;
      case PosterColorTheme.midnight:
        return Colors.white;
      case PosterColorTheme.light:
        return const Color(0xFF2B2B2B);
    }
  }
}

/// Horizontal scrollable selector for poster aspect ratio.
class PosterSizeSelector extends StatelessWidget {
  const PosterSizeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isBangla = false,
  });

  final PosterAspectRatio selected;
  final ValueChanged<PosterAspectRatio> onChanged;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBangla ? 'পোস্টার সাইজ' : 'Poster Size',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: PosterAspectRatio.values.map((ratio) {
            final isSelected = ratio == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: ratio != PosterAspectRatio.values.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () => onChanged(ratio),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : const Color(0xFFF3DDE0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ratio.label,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ratio.description,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Horizontal scrollable selector for poster color theme.
class PosterColorThemeSelector extends StatelessWidget {
  const PosterColorThemeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isBangla = false,
  });

  final PosterColorTheme selected;
  final ValueChanged<PosterColorTheme> onChanged;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBangla ? 'রঙের থিম' : 'Color Theme',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: PosterColorTheme.values.map((theme) {
            final isSelected = theme == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: theme != PosterColorTheme.values.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () => onChanged(theme),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE0D0D0),
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(60),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

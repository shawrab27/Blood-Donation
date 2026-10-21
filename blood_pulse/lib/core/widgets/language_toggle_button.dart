// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/locale_provider.dart';

/// Reusable Language Toggle Pill Button (EN / বাং)
/// Tapping it immediately switches application locale and persists choice to SharedPreferences.
class LanguageToggleButton extends ConsumerWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const LanguageToggleButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBangla = locale.languageCode == 'bn';

    final bg = backgroundColor ?? Colors.white;
    final textCol = textColor ?? const Color(0xFFC30121);
    final borderCol = borderColor ?? const Color(0xFFE2E2E2);

    return Semantics(
      button: true,
      label: isBangla ? 'Switch to English' : 'বাংলায় পরিবর্তন করুন',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('language_toggle_button'),
          onTap: () {
            ref.read(localeProvider.notifier).toggleLanguage();
          },
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: borderCol, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 15,
                  color: textCol,
                ),
                const SizedBox(width: 5),
                Text(
                  isBangla ? 'বাং' : 'EN',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textCol,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/locale_provider.dart';

/// Modal bottom sheet for choosing application locale (English / Bangla).
class LanguagePickerSheet extends ConsumerWidget {
  const LanguagePickerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isBangla = currentLocale.languageCode == 'bn';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.translate_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Select App Language',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: !isBangla ? const Color(0xFFFEE9EB) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language_rounded, color: !isBangla ? AppColors.primary : Colors.grey.shade600, size: 20),
              ),
              title: const Text('English (US)', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              subtitle: const Text('Default international interface', style: TextStyle(fontSize: 12)),
              trailing: !isBangla ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
              onTap: () {
                ref.read(localeProvider.notifier).setEnglish();
                Navigator.of(context).pop();
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBangla ? const Color(0xFFFEE9EB) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language_rounded, color: isBangla ? AppColors.primary : Colors.grey.shade600, size: 20),
              ),
              title: const Text('বাংলা (বাংলাদেশ)', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
              subtitle: const Text('সম্পূর্ণ বাংলা ইন্টারফেস', style: TextStyle(fontSize: 12)),
              trailing: isBangla ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
              onTap: () {
                ref.read(localeProvider.notifier).setBangla();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

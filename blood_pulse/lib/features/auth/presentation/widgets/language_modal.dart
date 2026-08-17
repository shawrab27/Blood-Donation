import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../providers/locale_provider.dart';

/// Language Selection Bottom Sheet Modal
///
/// Opened immediately upon pressing "Let's Start" on [SplashScreen].
/// Toggle pills: [ English | বাংলা ]
/// On "Continue" — sets global locale and navigates to Login.
class LanguageModal extends ConsumerWidget {
  const LanguageModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final isBangla = locale.languageCode == 'bn';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 28),

          // ── Blood drop icon ────────────────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE9EB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),

          const SizedBox(height: 16),

          // ── Title ──────────────────────────────────────────────────────
          const Text(
            'Choose Your Language',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'আপনার ভাষা নির্বাচন করুন',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.neutral,
            ),
          ),

          const SizedBox(height: 32),

          // ── Toggle Pills ───────────────────────────────────────────────
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF3DDE0),
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _LanguagePill(
                  label: 'English',
                  isSelected: !isBangla,
                  onTap: notifier.setEnglish,
                ),
                _LanguagePill(
                  label: 'বাংলা',
                  isSelected: isBangla,
                  onTap: notifier.setBangla,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Selected indicator ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                isBangla ? 'বাংলা নির্বাচিত' : 'English Selected',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Continue Button ────────────────────────────────────────────
          CapsuleButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            showGlow: true,
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.neutral,
            ),
          ),
        ),
      ),
    );
  }
}

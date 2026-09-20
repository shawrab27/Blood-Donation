import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/locale_provider.dart';

/// Language Selection Bottom Sheet Modal matching reference layout.
class LanguageModal extends ConsumerWidget {
  const LanguageModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final isBangla = locale.languageCode == 'bn';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8F7),
            borderRadius: BorderRadius.all(Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Official BloodPulse Logo & Brand Name ─────────
              const BloodPulseLogo(
                direction: Axis.vertical,
                iconSize: 56.0,
                fontSize: 26.0,
                spacing: 12.0,
              ),
              const SizedBox(height: 24),

              // ── Outer Card Wrapper ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    // ── Header Text ──
                    const Text(
                      'Select Language',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ভাষা নির্বাচন করুন',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC30121),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Custom Capsule Toggle Pills ──
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF3F3),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: notifier.setEnglish,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !isBangla ? const Color(0xFFC30121) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'English',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: !isBangla ? Colors.white : const Color(0xFF666666),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: notifier.setBangla,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isBangla ? const Color(0xFFC30121) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'বাংলা',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isBangla ? Colors.white : const Color(0xFF666666),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Description ──
                    const Text(
                      'Choose your preferred language to proceed with donation services.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF888888),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Continue Button ──
                    SizedBox(
                      width: double.infinity,
                      child: CapsuleButton(
                        label: isBangla ? 'চালিয়ে যান / এগিয়ে যান' : 'Continue / এগিয়ে যান',
                        icon: Icons.arrow_forward_rounded,
                        showGlow: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go('/login');
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Footer ──
              const Text(
                'Trusted by 2M+ Donors Worldwide',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


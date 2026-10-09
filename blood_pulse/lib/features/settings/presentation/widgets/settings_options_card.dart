// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/pulse_ai_visibility_provider.dart';
import '../../../auth/presentation/providers/locale_provider.dart';
import 'language_picker_sheet.dart';
import 'contact_us_sheet.dart';

/// Primary Settings Options Card matching Stitch Screen 5 (7 Items + AI Assistant toggle).
class SettingsOptionsCard extends ConsumerStatefulWidget {
  const SettingsOptionsCard({super.key});

  @override
  ConsumerState<SettingsOptionsCard> createState() => _SettingsOptionsCardState();
}

class _SettingsOptionsCardState extends ConsumerState<SettingsOptionsCard> {
  bool _notificationsReceived = true;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $e'), backgroundColor: AppColors.primary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final isBangla = currentLocale.languageCode == 'bn';
    final isPulseAiVisible = ref.watch(pulseAiVisibilityProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Language
          _buildTile(
            icon: Icons.translate_rounded,
            iconBgColor: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            title: 'Language',
            subtitle: isBangla ? 'বাংলা (BD)' : 'English (US)',
            onTap: () => LanguagePickerSheet.show(context),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 2. Notification Received
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_rounded, color: Color(0xFF004B7E), size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Notification Received',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF24191A),
                        ),
                      ),
                      Text(
                        'Urgent requests & updates',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF5C3F3D),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _notificationsReceived,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFFE4E2E1),
                  onChanged: (val) => setState(() => _notificationsReceived = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // PulseAI Assistant Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE9EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Show PulseAI assistant',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF24191A),
                        ),
                      ),
                      Text(
                        'Floating clinical AI companion',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF5C3F3D),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isPulseAiVisible,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFFE4E2E1),
                  onChanged: (val) {
                    ref.read(pulseAiVisibilityProvider.notifier).setVisible(val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 3. Privacy Policy
          _buildTile(
            icon: Icons.verified_user_rounded,
            iconBgColor: const Color(0xFFFFDAD7),
            iconColor: AppColors.primary,
            title: 'Privacy Policy',
            subtitle: 'Terms, security & blood safety',
            onTap: () => context.push('/privacy-policy'),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 4. Rate Us
          _buildTile(
            icon: Icons.star_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF004B7E),
            title: 'Rate Us',
            subtitle: 'Share your experience on App Store',
            onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.bloodpulse.app'),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 5. Share App
          _buildTile(
            icon: Icons.send_rounded,
            iconBgColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF7E22CE),
            title: 'Share App',
            subtitle: 'Spread the word, save lives',
            onTap: () {
              SharePlus.instance.share(
                ShareParams(
                  text: '🩸 Join me on BloodPulse - The Smart Blood Donation Network!\n'
                      'Find donors, respond to emergency hospital requests, and save lives today.\n'
                      'Download: https://bloodpulse.org/download',
                  subject: 'Join BloodPulse',
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 6. Learn More
          _buildTile(
            icon: Icons.info_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF004B7E),
            title: 'Learn More',
            subtitle: 'About BloodPulse & missions',
            onTap: () => context.push('/health-hub/science-of-blood'),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 7. Contact Us
          _buildTile(
            icon: Icons.support_agent_rounded,
            iconBgColor: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            title: 'Contact Us',
            subtitle: '24/7 Support & emergency helpline',
            onTap: () => ContactUsSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF5C3F3D),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF916F6C)),
          ],
        ),
      ),
    );
  }
}

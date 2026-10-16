// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/locale_provider.dart';
import '../../../profile/domain/providers/profile_provider.dart';
import 'language_picker_sheet.dart';
import 'contact_us_sheet.dart';

/// Primary Settings Options Card matching Stitch Screen 5 (Settings).
/// Strictly contains the exact 7 options from the design:
/// 1. Language
/// 2. Notification Received (Urgent requests & updates toggle)
/// 3. Privacy Policy
/// 4. Rate Us
/// 5. Share App
/// 6. Learn More
/// 7. Contact Us
class SettingsOptionsCard extends ConsumerStatefulWidget {
  const SettingsOptionsCard({super.key});

  @override
  ConsumerState<SettingsOptionsCard> createState() => _SettingsOptionsCardState();
}

class _SettingsOptionsCardState extends ConsumerState<SettingsOptionsCard> {
  bool _isUpdating = false;

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

  Future<void> _updateField(String key, dynamic value) async {
    setState(() => _isUpdating = true);
    final success = await ref.read(profileProvider.notifier).updateProfile({key: value});
    if (mounted) {
      setState(() => _isUpdating = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update setting. Please check your connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final isBangla = currentLocale.languageCode == 'bn';
    final profile = ref.watch(profileProvider).valueOrNull;
    final notificationsEnabled = profile?.notificationsEnabled ?? true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
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
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 2. Notification Received (Urgent requests & updates)
          _buildSwitchTile(
            icon: Icons.notifications_rounded,
            iconBgColor: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Notification Received',
            subtitle: 'Urgent requests & updates',
            value: notificationsEnabled,
            onChanged: _isUpdating ? null : (val) => _updateField('notifications_enabled', val),
          ),
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 3. Privacy Policy (Terms, security & blood safety)
          _buildTile(
            icon: Icons.shield_outlined,
            iconBgColor: const Color(0xFFFFDAD7),
            iconColor: const Color(0xFFC30121),
            title: 'Privacy Policy',
            subtitle: 'Terms, security & blood safety',
            onTap: () => context.push('/privacy-policy'),
          ),
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 4. Devices & Sessions (Manage active logins & devices)
          _buildTile(
            icon: Icons.devices_rounded,
            iconBgColor: const Color(0xFFFDEAEB),
            iconColor: const Color(0xFFC30121),
            title: 'Devices & Sessions',
            subtitle: 'Manage active logins & devices',
            onTap: () => context.push('/settings/devices'),
          ),
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 4. Rate Us (Share your experience on App Store)
          _buildTile(
            icon: Icons.star_outline_rounded,
            iconBgColor: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Rate Us',
            subtitle: 'Share your experience on App Store',
            onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.bloodpulse.app'),
          ),
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 5. Share App (Spread the word, save lives)
          _buildTile(
            icon: Icons.near_me_outlined,
            iconBgColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF7C3AED),
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
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 6. Learn More (About BloodPulse & missions)
          _buildTile(
            icon: Icons.info_outline_rounded,
            iconBgColor: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Learn More',
            subtitle: 'About BloodPulse & missions',
            onTap: () => context.push('/health-hub/science-of-blood'),
          ),
          Divider(height: 1, indent: 64, color: const Color(0xFFF3DDE0).withValues(alpha: 0.6)),

          // 7. Contact Us (24/7 Support & emergency helpline)
          _buildTile(
            icon: Icons.headset_mic_outlined,
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

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF24191A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFC30121),
            inactiveTrackColor: const Color(0xFFE4E2E1),
            onChanged: onChanged,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
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
                      fontSize: 15,
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
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFC8C6C5)),
          ],
        ),
      ),
    );
  }
}

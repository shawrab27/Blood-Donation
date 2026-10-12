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
import '../../../profile/domain/providers/profile_provider.dart';
import '../../../profile/domain/providers/leaderboard_provider.dart';
import 'language_picker_sheet.dart';
import 'contact_us_sheet.dart';

/// Primary Settings Options Card matching Stitch Screen 5.
/// 100% dynamically wired to backend privacy, notifications, and clinical settings.
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
    if (key == 'public_profile') {
      ref.invalidate(leaderboardProvider);
    }
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
    final isPulseAiVisible = ref.watch(pulseAiVisibilityProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    final notificationsEnabled = profile?.notificationsEnabled ?? true;
    final emergencyAlertsEnabled = profile?.emergencyAlertsEnabled ?? true;
    final showContact = profile?.showContact ?? false;
    final publicProfile = profile?.publicProfile ?? false;

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

          // 2. Notifications Enabled
          _buildSwitchTile(
            icon: Icons.notifications_rounded,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF004B7E),
            title: 'Notification Received',
            subtitle: 'Urgent requests & donor reminders',
            value: notificationsEnabled,
            onChanged: _isUpdating ? null : (val) => _updateField('notifications_enabled', val),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 3. Emergency Alerts Enabled
          _buildSwitchTile(
            icon: Icons.notification_important_rounded,
            iconBgColor: const Color(0xFFFFEAEA),
            iconColor: AppColors.primary,
            title: 'Emergency Alerts',
            subtitle: 'Critical patient alerts in your district',
            value: emergencyAlertsEnabled,
            onChanged: _isUpdating ? null : (val) => _updateField('emergency_alerts_enabled', val),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 4. Show Contact Phone
          _buildSwitchTile(
            icon: Icons.phone_enabled_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Show Contact Phone',
            subtitle: 'Allow verified patients to call you directly',
            value: showContact,
            onChanged: _isUpdating ? null : (val) => _updateField('show_contact', val),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 5. Public Profile / Leaderboard Consent
          _buildSwitchTile(
            icon: Icons.leaderboard_rounded,
            iconBgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
            title: 'Public Profile & Leaderboard',
            subtitle: 'Show your name on top donor rankings',
            value: publicProfile,
            onChanged: _isUpdating ? null : (val) => _updateField('public_profile', val),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 6. PulseAI Assistant Toggle
          _buildSwitchTile(
            icon: Icons.support_agent_rounded,
            iconBgColor: const Color(0xFFFEE9EB),
            iconColor: AppColors.primary,
            title: 'Show PulseAI Assistant',
            subtitle: 'Floating clinical AI companion',
            value: isPulseAiVisible,
            onChanged: (val) {
              ref.read(pulseAiVisibilityProvider.notifier).setVisible(val);
            },
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 7. Privacy Policy
          _buildTile(
            icon: Icons.verified_user_rounded,
            iconBgColor: const Color(0xFFFFDAD7),
            iconColor: AppColors.primary,
            title: 'Privacy Policy',
            subtitle: 'Terms, security & blood safety',
            onTap: () => context.push('/privacy-policy'),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 8. Rate Us
          _buildTile(
            icon: Icons.star_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF004B7E),
            title: 'Rate Us',
            subtitle: 'Share your experience on App Store',
            onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.bloodpulse.app'),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 9. Share App
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

          // 10. Learn More
          _buildTile(
            icon: Icons.info_rounded,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF004B7E),
            title: 'Learn More',
            subtitle: 'About BloodPulse & missions',
            onTap: () => context.push('/health-hub/science-of-blood'),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // 11. Contact Us
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
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF5C3F3D),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
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

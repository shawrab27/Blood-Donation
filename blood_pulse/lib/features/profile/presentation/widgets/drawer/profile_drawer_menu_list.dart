// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import '../../../../../core/providers/pulse_ai_visibility_provider.dart';
import 'drawer_donate_sheet.dart';
import 'drawer_learn_more_sheet.dart';

/// Navigation menu items inside Profile Drawer matching Stitch Screen 4.
class ProfileDrawerMenuList extends ConsumerWidget {
  const ProfileDrawerMenuList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPulseAiVisible = ref.watch(pulseAiVisibilityProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
      ),
      child: Column(
        children: [
          _buildItem(
            icon: Icons.favorite_rounded,
            title: 'Donate to BloodPulse',
            subtitle: 'Support voluntary operations & supplies',
            onTap: () => DrawerDonateSheet.show(context),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          _buildItem(
            icon: Icons.notifications_none_rounded,
            title: 'Inbox & Notifications',
            subtitle: 'Direct hospital requests & matches',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/notifications');
            },
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          _buildItem(
            icon: Icons.help_outline_rounded,
            title: 'FAQ & Donor Guide',
            subtitle: 'Preparation, recovery, & safety rules',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/health-hub/donation-guide');
            },
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          // PulseAI Floating Assistant Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'PulseAI Assistant',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF24191A),
                        ),
                      ),
                      Text(
                        'Floating shortcut on main screen',
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
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    ref.read(pulseAiVisibilityProvider.notifier).setVisible(val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          _buildItem(
            icon: Icons.support_agent_rounded,
            title: 'Chat with PulseAI',
            subtitle: 'Get instant clinical answers',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/assistant');
            },
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          _buildItem(
            icon: Icons.settings_outlined,
            title: 'Settings & Security',
            subtitle: 'SOS alarms, privacy & phone visibility',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/settings');
            },
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          _buildItem(
            icon: Icons.menu_book_rounded,
            title: 'Learn More',
            subtitle: 'Eligibility, process & blood facts',
            onTap: () => DrawerLearnMoreSheet.show(context),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),
          _buildItem(
            icon: Icons.share_outlined,
            title: 'Share App',
            subtitle: 'Invite friends & family to save lives',
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
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Color(0xFFFDF3F3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

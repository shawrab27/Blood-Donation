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
          // 1. Donate to BloodPulse
          _buildItem(
            icon: Icons.favorite_border_rounded,
            title: 'Donate to BloodPulse',
            subtitle: 'Support voluntary operations & supplies',
            onTap: () => DrawerDonateSheet.show(context),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

          // 2. Inbox & Notifications
          _buildItem(
            icon: Icons.mail_outline_rounded,
            title: 'Inbox & Notifications',
            subtitle: 'Direct hospital requests & matches',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/notifications');
            },
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

          // 3. FAQ & Donor Guide
          _buildItem(
            icon: Icons.history_rounded,
            title: 'FAQ & Donor Guide',
            subtitle: 'Preparation, recovery, & safety rules',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/health-hub/donation-guide');
            },
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

          // 4. PulseAI (with AI badge and toggle switch)
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
              context.push('/assistant');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(
                      'assets/images/pulseai_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.water_drop_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'PulseAI',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF24191A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFDAD6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF93000A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Clinical chatbot & donor guidance',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(0xFF5C3F3D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isPulseAiVisible,
                      activeColor: Colors.white,
                      activeTrackColor: AppColors.primary,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFE4E2E1),
                      onChanged: (val) {
                        ref.read(pulseAiVisibilityProvider.notifier).setVisible(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

          // 5. Settings & Security
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

          // 6. Learn More
          _buildItem(
            icon: Icons.menu_book_outlined,
            title: 'Learn More',
            subtitle: 'Eligibility, process & blood facts',
            onTap: () => DrawerLearnMoreSheet.show(context),
          ),
          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

          // 7. Share App
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 16),
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
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Color(0xFF5C3F3D),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFC8C6C5)),
          ],
        ),
      ),
    );
  }
}

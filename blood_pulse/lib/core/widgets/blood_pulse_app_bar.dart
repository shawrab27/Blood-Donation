import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'app_logo_slot.dart';

/// The official standard header for BloodPulse.
///
/// Features:
///   • Top-Left: Logo asset ("assets/images/Blood Pulse logo.jpg") + "BloodPulse" title (Georgia font, deep red #C30121).
///   • Top-Right:
///       1. Notification bell icon with unread badge (triggers data refresh / notification dialog).
///       2. 3-Dot vertical menu button with options: Learn more, Contact us, About us, Log out.
class BloodPulseAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BloodPulseAppBar({
    super.key,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.onNotificationTap,
    this.logoSize = AppLogoSize.header,
  });

  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onNotificationTap;
  final double logoSize;

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  void _showMenuOptionDialog(BuildContext context, String title, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: AppColors.secondary)),
        content: Text(content, style: const TextStyle(fontFamily: 'Inter', height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Confirm Logout', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your BloodPulse account?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/login');
            },
            child: const Text('Log Out', style: TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.secondary),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Top-Left Logo & "BloodPulse" Name
          AppLogoSlot(size: logoSize),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BloodPulse',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutral,
                  ),
                ),
            ],
          ),
        ],
      ),

      // Top-Right Actions
      actions: [
        // Notification Bell Icon with active unread badge
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.secondary, size: 24),
              onPressed: () {
                if (onNotificationTap != null) {
                  onNotificationTap!();
                } else {
                  context.push('/notifications');
                }
              },
            ),
            Positioned(
              right: 10,
              top: 12,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),

        // 3-Dot Vertical Menu Button
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) {
            switch (value) {
              case 'learn_more':
                _showMenuOptionDialog(
                  context,
                  'Learn More about BloodPulse',
                  'BloodPulse is Bangladesh\'s premier national emergency blood matching network. Powered by AI document verification, real-time geolocation matching, and WHO eligibility engines.',
                );
                break;
              case 'contact_us':
                _showMenuOptionDialog(
                  context,
                  'Contact Us',
                  'Emergency Hotline: 16263 / +880 9612-000999\nEmail: support@bloodpulse.org\nHeadquarters: Dhaka Medical College Zone, Bangladesh.',
                );
                break;
              case 'about_us':
                _showMenuOptionDialog(
                  context,
                  'About BloodPulse',
                  'Version 1.0.0 (Phase 3 Build)\nDeveloped under Clean Architecture with Flutter & Firebase backend integration.',
                );
                break;
              case 'logout':
                _showLogoutDialog(context);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'learn_more',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.secondary),
                  SizedBox(width: 10),
                  Text('Learn more', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'contact_us',
              child: Row(
                children: [
                  Icon(Icons.contact_support_outlined, size: 18, color: AppColors.secondary),
                  SizedBox(width: 10),
                  Text('Contact us', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'about_us',
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 18, color: AppColors.secondary),
                  SizedBox(width: 10),
                  Text('About us', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Log out', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

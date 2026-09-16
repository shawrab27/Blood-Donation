import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/locale_provider.dart';
import '../theme/app_colors.dart';
import 'app_logo_slot.dart';

/// The official standard header for BloodPulse.
///
/// Features:
///   • Top-Left: Logo asset ("assets/images/Blood Pulse logo.jpg") + "BloodPulse" title (Georgia font, deep red #C30121).
///   • Top-Right:
///       1. Notification bell icon with unread badge (triggers data refresh / notification dialog).
///       2. 3-Dot vertical menu button with options: Language Toggle, Learn more, Contact us, About us, Log out.
class BloodPulseAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const BloodPulseAppBar({
    super.key,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.onNotificationTap,
    this.logoSize = AppLogoSize.header,
    this.showLogo = true,
  });

  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onNotificationTap;
  final double logoSize;
  final bool showLogo;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLocale = ref.watch(localeProvider);
    final isBangla = activeLocale.languageCode == 'bn';

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

          // Top-Left Logo & Title OR Page Header
          if (showLogo) ...[
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
          ] else ...[
            Text(
              subtitle ?? 'BloodPulse',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
                letterSpacing: -0.3,
              ),
            ),
          ],
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

        // 3-Dot Vertical Menu Button with Language Switcher
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) {
            switch (value) {
              case 'toggle_language':
                ref.read(localeProvider.notifier).toggleLanguage();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isBangla ? 'Language switched to English' : 'ভাষা বাংলায় পরিবর্তিত হয়েছে',
                      style: const TextStyle(fontFamily: 'Inter'),
                    ),
                    backgroundColor: AppColors.tertiary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
                break;
              case 'learn_more':
                _showMenuOptionDialog(
                  context,
                  isBangla ? 'ব্লাডপালস সম্পর্কে জানুন' : 'Learn More about BloodPulse',
                  isBangla
                      ? 'ব্লাডপালস বাংলাদেশের প্রধান জাতীয় জরুরি রক্ত মেলানো নেটওয়ার্ক।'
                      : 'BloodPulse is Bangladesh\'s premier national emergency blood matching network. Powered by AI document verification, real-time geolocation matching, and WHO eligibility engines.',
                );
                break;
              case 'contact_us':
                _showMenuOptionDialog(
                  context,
                  isBangla ? 'যোগাযোগ করুন' : 'Contact Us',
                  'Emergency Hotline: 16263 / +880 9612-000999\nEmail: support@bloodpulse.org\nHeadquarters: Dhaka Medical College Zone, Bangladesh.',
                );
                break;
              case 'about_us':
                _showMenuOptionDialog(
                  context,
                  isBangla ? 'আমাদের সম্পর্কে' : 'About BloodPulse',
                  'Version 1.0.0 (Phase 3 Build)\nDeveloped under Clean Architecture with Flutter & Firebase backend integration.',
                );
                break;
              case 'logout':
                _showLogoutDialog(context);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_language',
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, size: 18, color: AppColors.tertiary),
                  const SizedBox(width: 10),
                  Text(
                    isBangla ? 'Switch to English' : 'বাংলায় দেখুন (বাংলা)',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.tertiary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'learn_more',
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Text(isBangla ? 'আরও জানুন' : 'Learn more', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'contact_us',
              child: Row(
                children: [
                  const Icon(Icons.contact_support_outlined, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Text(isBangla ? 'যোগাযোগ করুন' : 'Contact us', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'about_us',
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Text(isBangla ? 'আমাদের সম্পর্কে' : 'About us', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    isBangla ? 'লগ আউট' : 'Log out',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
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

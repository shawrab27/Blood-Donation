import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/providers/locale_provider.dart';
import '../../features/profile/domain/providers/profile_provider.dart';

/// Comprehensive Slide-out Profile & Preferences Drawer for BloodPulse.
///
/// Direct parity with Stitch Screen `7186416657104bbfb62aa038581baf03`
/// and `.agents/AGENTS.md` guidelines.
class ProfileDrawer extends ConsumerStatefulWidget {
  const ProfileDrawer({super.key});

  /// Opens the drawer smoothly from the right side of the screen.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Profile Drawer',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Align(
          alignment: Alignment.centerRight,
          child: ProfileDrawer(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends ConsumerState<ProfileDrawer> {
  int _selectedThemeIndex = 0; // 0: System, 1: Light, 2: Dark

  Future<void> _launchExternalUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open: $urlString'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE9EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Log Out',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your BloodPulse session?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4A4A4A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              Navigator.of(context).pop(); // Close drawer
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Log Out', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Account',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your BloodPulse account and donor record?\n\nThis action cannot be undone. All your donor statistics, matches, and requests will be removed.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4A4A4A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // Close dialog
              final messenger = ScaffoldMessenger.of(context);
              final success = await ref.read(authProvider.notifier).deleteAccount(
                onError: (error) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              );
              if (success) {
                if (mounted) {
                  Navigator.of(context).pop(); // Close drawer
                  context.go('/login');
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Your account and donor records have been deleted.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
            child: const Text('Yes, Delete', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLearnMoreModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'About BloodPulse',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mission Statement',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'BloodPulse is a community-driven blood donation management network designed to eliminate emergency blood shortages. We connect voluntary donors with emergency patients, verified trauma centers, and regional blood banks in minutes.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Who Can Donate?',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Age between 18 and 60 years old\n• Weight of at least 45 kg (or 50 kg for platelets)\n• Hemoglobin level ≥ 12.5 g/dL\n• At least 90-120 days since last whole blood donation\n• Healthy with no active fever or antibiotic intake',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.6, color: Color(0xFF555555)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '100% Free & Community Dedicated',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'BloodPulse charges zero fees to patients, donors, or hospitals. Blood donation is an act of humanitarian kindness.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactUsModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: AppColors.tertiary, size: 26),
                const SizedBox(width: 8),
                const Text(
                  'Contact & Support',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'We are here 24/7 for emergency blood coordination and platform inquiries.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFFEE9EB), shape: BoxShape.circle),
                child: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 20),
              ),
              title: const Text('Emergency Health Helpline', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('16263 (National Toll-Free Health Hotline)', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () => _launchExternalUrl('tel:16263'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFE8F1F8), shape: BoxShape.circle),
                child: const Icon(Icons.email_outlined, color: AppColors.tertiary, size: 20),
              ),
              title: const Text('Support Email', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('support@bloodpulse.org', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () => _launchExternalUrl('mailto:support@bloodpulse.org'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                child: const Icon(Icons.language_rounded, color: Colors.black87, size: 20),
              ),
              title: const Text('Official Portal', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('https://bloodpulse.org', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () => _launchExternalUrl('https://bloodpulse.org'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);
    final currentLocale = ref.watch(localeProvider);
    final isBangla = currentLocale.languageCode == 'bn';

    String displayName = authState.user?.fullName.trim().isNotEmpty == true
        ? authState.user!.fullName
        : 'Sarah Jenkins';
    String displayInitials = 'SJ';

    profileAsync.whenData((p) {
      if (p != null) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        if (name.isNotEmpty) {
          displayName = name;
        } else if (p.username != null && p.username!.isNotEmpty) {
          displayName = p.username!;
        }
      }
    });

    final parts = displayName.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      displayInitials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (displayName.isNotEmpty) {
      displayInitials = displayName[0].toUpperCase();
    }

    final double drawerWidth = MediaQuery.of(context).size.width.clamp(300.0, 360.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8F7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(-4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/Blood Pulse logo.jpg',
                            height: 28,
                            width: 28,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'BloodPulse',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF2B2B2B),
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'ACCOUNT & PREFERENCES',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 8.5,
                                color: AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF2B2B2B)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE9EB),
                        padding: const EdgeInsets.all(6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF3DDE0)),

              // ── Scrollable Menu Body ──
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    // ── User Identity Hero Card ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF850014),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF850014).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white,
                            child: Text(
                              displayInitials,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF850014),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go('/profile');
                            },
                            child: const Text(
                              'View Profile',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Appearance Theme Selector ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3DDE0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.dark_mode_outlined, size: 14, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Appearance Theme',
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2B2B2B)),
                                  ),
                                ],
                              ),
                              Text(
                                'AUTO SWITCH',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF3F3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildThemePill(0, 'System', Icons.devices_rounded),
                                _buildThemePill(1, 'Light', Icons.light_mode_outlined),
                                _buildThemePill(2, 'Dark', Icons.nightlight_round_outlined),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Main Preferences & Actions Menu Group ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3DDE0)),
                      ),
                      child: Column(
                        children: [
                          // 1. Donate to BloodPulse
                          _buildMenuItem(
                            icon: Icons.favorite_rounded,
                            iconColor: AppColors.primary,
                            title: 'Donate to BloodPulse',
                            subtitle: 'Support voluntary operations & supplies',
                            onTap: () => _launchExternalUrl('https://buymeacoffee.com/bloodpulse'),
                          ),
                          const Divider(height: 1, indent: 52),

                          // 2. Inbox & Notifications
                          _buildMenuItem(
                            icon: Icons.notifications_none_rounded,
                            iconColor: AppColors.primary,
                            title: 'Inbox & Notifications',
                            subtitle: 'Direct hospital requests & matches',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/notifications');
                            },
                          ),
                          const Divider(height: 1, indent: 52),

                          // 3. FAQ & Donor Guide
                          _buildMenuItem(
                            icon: Icons.help_outline_rounded,
                            iconColor: AppColors.tertiary,
                            title: 'FAQ & Donor Guide',
                            subtitle: 'Preparation, recovery, & safety rules',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/health-hub/guide');
                            },
                          ),
                          const Divider(height: 1, indent: 52),

                          // 4. Settings & Security
                          _buildMenuItem(
                            icon: Icons.settings_outlined,
                            iconColor: const Color(0xFF2B2B2B),
                            title: 'Settings & Security',
                            subtitle: 'SOS alarms, privacy & phone visibility',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/settings');
                            },
                          ),
                          const Divider(height: 1, indent: 52),

                          // 5. Language Toggle (English / বাংলা)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFDF3F3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.translate_rounded, color: AppColors.primary, size: 17),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Language / ভাষা',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                                      ),
                                      Text(
                                        isBangla ? 'বাংলা মোড সক্রিয়' : 'English Mode Active',
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF3F3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('en')),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: !isBangla ? AppColors.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'EN',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: !isBangla ? Colors.white : const Color(0xFF666666),
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('bn')),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isBangla ? AppColors.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'বাং',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isBangla ? Colors.white : const Color(0xFF666666),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 52),

                          // 6. Rate Us
                          _buildMenuItem(
                            icon: Icons.star_outline_rounded,
                            iconColor: const Color(0xFFE5A100),
                            title: 'Rate Us',
                            subtitle: 'Support with 5 stars on Play Store',
                            onTap: () => _launchExternalUrl('https://play.google.com/store/apps/details?id=com.bloodpulse.app'),
                          ),
                          const Divider(height: 1, indent: 52),

                          // 7. Share App
                          _buildMenuItem(
                            icon: Icons.share_outlined,
                            iconColor: AppColors.tertiary,
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
                          const Divider(height: 1, indent: 52),

                          // 8. Learn More
                          _buildMenuItem(
                            icon: Icons.info_outline_rounded,
                            iconColor: const Color(0xFF555555),
                            title: 'Learn More',
                            subtitle: 'Eligibility, process & blood facts',
                            onTap: _showLearnMoreModal,
                          ),
                          const Divider(height: 1, indent: 52),

                          // 9. Contact Us
                          _buildMenuItem(
                            icon: Icons.support_agent_rounded,
                            iconColor: const Color(0xFF1B8A4E),
                            title: 'Contact Us',
                            subtitle: '24/7 Support & emergency helpline',
                            onTap: _showContactUsModal,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Account Switching & Danger Options ──
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF3DDE0)),
                      ),
                      child: Column(
                        children: [
                          // 10. Create New Account (Switch)
                          _buildMenuItem(
                            icon: Icons.person_add_outlined,
                            iconColor: AppColors.primary,
                            title: 'Create New Account',
                            subtitle: 'Register another donor profile or organization',
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text('Switch Account', style: TextStyle(fontFamily: 'Georgia')),
                                  content: const Text('Do you want to log out of this account and register a new one?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).pop();
                                        ref.read(authProvider.notifier).logout();
                                        context.go('/register');
                                      },
                                      child: const Text('Register New', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 52),

                          // 11. Delete Account
                          _buildMenuItem(
                            icon: Icons.delete_outline_rounded,
                            iconColor: Colors.red.shade700,
                            title: 'Delete Account',
                            titleColor: Colors.red.shade700,
                            subtitle: 'Permanently erase donor profile & data',
                            onTap: _showDeleteAccountConfirmation,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── 12. Log Out Button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: _showLogoutConfirmation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Log Out',
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePill(int index, String label, IconData icon) {
    final isSelected = _selectedThemeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedThemeIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isSelected ? AppColors.primary : const Color(0xFF666666)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: titleColor ?? const Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFF888888),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFB0B0B0)),
            ],
          ),
        ),
      ),
    );
  }
}

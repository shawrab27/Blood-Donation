import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/domain/providers/profile_provider.dart';

/// 1:1 Parity with Stitch Screen `7186416657104bbfb62aa038581baf03`
/// and user-uploaded reference `media_1789865014647.png`.
///
/// Features:
///   • Branded Header: BloodPulse logo + "ACCOUNT & PREFERENCES" + Close button
///   • Burgundy User Identity Hero Card with initials avatar and "View Profile" CTA
///   • Dynamic Appearance Theme Segment Selector (System / Light / Dark)
///   • 6 Dedicated Navigation Menu items with soft circular icons & chevrons
///   • Full capsule "Log Out ➔" button with modal confirmation
class ProfileDrawer extends ConsumerStatefulWidget {
  const ProfileDrawer({super.key});

  /// Smooth slide-in from the right edge with backdrop blur.
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

  void _showDonateModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFFFEE9EB), shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Support BloodPulse',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'BloodPulse is 100% voluntary, community-funded, and free for all emergency patients. Your contribution helps sustain emergency SMS dispatch and hospital coordination.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _launchExternalUrl('https://buymeacoffee.com/bloodpulse');
                },
                child: const Text('Donate Online (Buy Us a Coffee)', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showLearnMoreModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.72,
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
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mission & Vision',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'BloodPulse is a community-driven blood donation management network designed to eliminate emergency blood shortages. We connect voluntary donors with emergency patients, verified trauma centers, and regional blood banks in minutes.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Eligibility & Health Rules',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Age: 18 to 60 years old\n• Weight: At least 45 kg (or 50 kg for platelets)\n• Hemoglobin: ≥ 12.5 g/dL\n• Donation Interval: 90–120 days since last donation\n• Healthy with no active fever or antibiotic medications',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.6, color: Color(0xFF555555)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '100% Free & Transparent',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'BloodPulse charges zero fees to patients, donors, or hospitals. Blood donation is a pure act of humanitarian kindness.',
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    final authUser = authState.user;
    final Uint8List? avatarBytes = authUser?.avatarBytes;
    final String? photoUrl = authUser?.photoUrl;

    String displayName = authUser?.fullName.trim().isNotEmpty == true
        ? authUser!.fullName
        : 'Blood Donor';
    String displayInitials = 'BD';

    profileAsync.whenData((p) {
      if (p != null) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        if (name.isNotEmpty && name != 'Dr. S. M. Shawrab') {
          displayName = name;
        } else if (p.username != null && p.username!.isNotEmpty && p.username != 'Dr. S. M. Shawrab') {
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

    final double drawerWidth = (MediaQuery.of(context).size.width * 0.84).clamp(300.0, 340.0);

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
              // ── Top Branded Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primary),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  children: [
                    // ── User Identity Hero Card ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF850014),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF850014).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            backgroundImage: (avatarBytes != null)
                                ? MemoryImage(avatarBytes)
                                : (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl) as ImageProvider
                                    : null,
                            child: (avatarBytes == null && (photoUrl == null || photoUrl.isEmpty))
                                ? Text(
                                    displayInitials,
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF850014),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
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

                    const SizedBox(height: 12),

                    // ── Appearance Theme Selector ──
                    Container(
                      padding: const EdgeInsets.all(10),
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
                                style: TextStyle(fontFamily: 'Inter', fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF9E9E9E)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF3F3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _buildThemePill(0, 'System', Icons.devices_rounded, themeMode == ThemeMode.system, () {
                                  themeNotifier.setSystem();
                                }),
                                _buildThemePill(1, 'Light', Icons.light_mode_outlined, themeMode == ThemeMode.light, () {
                                  themeNotifier.setLight();
                                }),
                                _buildThemePill(2, 'Dark', Icons.nightlight_round_outlined, themeMode == ThemeMode.dark, () {
                                  themeNotifier.setDark();
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Preferences Navigation Menu List (6 Items matching Stitch) ──
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
                            title: 'Donate to BloodPulse',
                            subtitle: 'Support voluntary operations & supplies',
                            onTap: _showDonateModal,
                          ),
                          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

                          // 2. Inbox & Notifications
                          _buildMenuItem(
                            icon: Icons.notifications_none_rounded,
                            title: 'Inbox & Notifications',
                            subtitle: 'Direct hospital requests & matches',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/notifications');
                            },
                          ),
                          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

                          // 3. FAQ & Donor Guide
                          _buildMenuItem(
                            icon: Icons.help_outline_rounded,
                            title: 'FAQ & Donor Guide',
                            subtitle: 'Preparation, recovery, & safety rules',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/health-hub/donation-guide');
                            },
                          ),
                          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

                          // 4. Settings & Security
                          _buildMenuItem(
                            icon: Icons.settings_outlined,
                            title: 'Settings & Security',
                            subtitle: 'SOS alarms, privacy & phone visibility',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/settings');
                            },
                          ),
                          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

                          // 5. Learn More
                          _buildMenuItem(
                            icon: Icons.menu_book_rounded,
                            title: 'Learn More',
                            subtitle: 'Eligibility, process & blood facts',
                            onTap: _showLearnMoreModal,
                          ),
                          const Divider(height: 1, indent: 48, color: Color(0xFFF3DDE0)),

                          // 6. Share App
                          _buildMenuItem(
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
                    ),

                    const SizedBox(height: 16),

                    // ── Log Out Button (Pill CTA) ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC30121),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _showLogoutConfirmation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Log Out',
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 15),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePill(int index, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
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

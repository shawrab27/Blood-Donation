import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/locale_provider.dart';
import '../../../profile/domain/providers/profile_provider.dart';

/// Settings & Security Screen for BloodPulse.
/// 1:1 Parity with Stitch Screen `2247f788f26042908aa418ba2bfd621f`
/// and user-uploaded reference `media_1789865014647.png`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsReceived = true;

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

  void _showLanguageBottomSheet() {
    final currentLocale = ref.read(localeProvider);
    final isBangla = currentLocale.languageCode == 'bn';

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.translate_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Select App Language',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: !isBangla ? const Color(0xFFFEE9EB) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.language_rounded, color: !isBangla ? AppColors.primary : Colors.grey.shade600, size: 20),
                ),
                title: const Text('English (US)', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                subtitle: const Text('Default international interface', style: TextStyle(fontSize: 12)),
                trailing: !isBangla ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setEnglish();
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBangla ? const Color(0xFFFEE9EB) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.language_rounded, color: isBangla ? AppColors.primary : Colors.grey.shade600, size: 20),
                ),
                title: const Text('বাংলা (বাংলাদেশ)', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                subtitle: const Text('সম্পূর্ণ বাংলা ইন্টারফেস', style: TextStyle(fontSize: 12)),
                trailing: isBangla ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setBangla();
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyModal() {
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
                const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Privacy & Blood Safety',
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
                      'Donor Data Protection',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your personal phone number and exact residential location are never publicly indexed. They are shared only with verified requesters once a life-saving blood match is officially confirmed.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Medical Confidentiality',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Diagnostic screening and transfusion histories are processed in compliance with healthcare data protection standards. BloodPulse never sells user information to pharmaceutical or commercial third parties.',
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
        height: MediaQuery.of(ctx).size.height * 0.52,
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
                const Icon(Icons.support_agent_rounded, color: Color(0xFFD97706), size: 26),
                const SizedBox(width: 8),
                const Text(
                  '24/7 Contact & Support',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Reach our voluntary dispatch and patient support helpline anytime.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFD97706), size: 20),
              ),
              title: const Text('Emergency Health Helpline', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('16263 (National Health Emergency Line)', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () => _launchExternalUrl('tel:16263'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                child: const Icon(Icons.email_outlined, color: Color(0xFF004B7E), size: 20),
              ),
              title: const Text('Direct Support Desk', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('support@bloodpulse.org', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
              onTap: () => _launchExternalUrl('mailto:support@bloodpulse.org'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                onPressed: () => Navigator.of(ctx).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDAD6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFBA1A1A), size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'Delete Account',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFBA1A1A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure, you want to delete account? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF5C3F3D)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE9EB),
                      foregroundColor: const Color(0xFF24191A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('No', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBA1A1A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await ref.read(authProvider.notifier).deleteAccount(
                        onError: (error) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error), backgroundColor: Colors.red),
                          );
                        },
                      );
                      if (success && mounted) {
                        context.go('/login');
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Account permanently deleted.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    child: const Text('Yes, Delete', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                onPressed: () => Navigator.of(ctx).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDAD7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'Log Out',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure, you want to logout?',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF5C3F3D)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE9EB),
                      foregroundColor: const Color(0xFF24191A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                    child: const Text('Logout', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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
    String bloodGroup = authState.user?.bloodGroup ?? 'O+';
    int totalDonations = authState.user?.totalBagsDonated ?? 4;
    String? photoUrl;

    profileAsync.whenData((p) {
      if (p != null) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        if (name.isNotEmpty) {
          displayName = name;
        }
        if (p.bloodGroup != null && p.bloodGroup!.isNotEmpty) {
          bloodGroup = p.bloodGroup!;
        }
        if (p.totalBagsDonated > 0) {
          totalDonations = p.totalBagsDonated;
        }
        photoUrl = p.profilePicture;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: CustomAppBar(
        title: 'Settings',
        titleColor: AppColors.primary,
        showLogo: false,
        showBackButton: true,
        showNotification: false,
        showProfile: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
      ),
      body: ResponsiveCenterWrapper(
        maxWidth: 540,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Top Donor Snapshot Card ──
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFEE9EB),
                    backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                        ? NetworkImage(photoUrl!)
                        : null,
                    child: photoUrl == null || photoUrl!.isEmpty
                        ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 26)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Blood Donor • Type $bloodGroup',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF5C3F3D),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalDonations Donated',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Primary Settings Card (7 Items) ──
            Container(
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
                  _buildSettingsTile(
                    icon: Icons.translate_rounded,
                    iconBgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Language',
                    subtitle: isBangla ? 'বাংলা (BD)' : 'English (US)',
                    onTap: _showLanguageBottomSheet,
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
                          onChanged: (val) {
                            setState(() => _notificationsReceived = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

                  // 3. Privacy Policy
                  _buildSettingsTile(
                    icon: Icons.verified_user_rounded,
                    iconBgColor: const Color(0xFFFFDAD7),
                    iconColor: AppColors.primary,
                    title: 'Privacy Policy',
                    subtitle: 'Terms, security & blood safety',
                    onTap: _showPrivacyPolicyModal,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

                  // 4. Rate Us
                  _buildSettingsTile(
                    icon: Icons.star_rounded,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF004B7E),
                    title: 'Rate Us',
                    subtitle: 'Share your experience on App Store',
                    onTap: () => _launchExternalUrl('https://play.google.com/store/apps/details?id=com.bloodpulse.app'),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

                  // 5. Share App
                  _buildSettingsTile(
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
                  _buildSettingsTile(
                    icon: Icons.info_rounded,
                    iconBgColor: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF004B7E),
                    title: 'Learn More',
                    subtitle: 'About BloodPulse & missions',
                    onTap: () => context.push('/health-hub/science-of-blood'),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

                  // 7. Contact Us
                  _buildSettingsTile(
                    icon: Icons.support_agent_rounded,
                    iconBgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Contact Us',
                    subtitle: '24/7 Support & emergency helpline',
                    onTap: _showContactUsModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Account & Danger Actions Card (3 Items) ──
            Container(
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
                  // Create New Account
                  _buildSettingsTile(
                    icon: Icons.person_add_rounded,
                    iconBgColor: const Color(0xFFF8E3E5),
                    iconColor: AppColors.primary,
                    title: 'Create New Account',
                    subtitle: 'Register another donor profile or organization',
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Create New Account', style: TextStyle(fontFamily: 'Georgia')),
                          content: const Text('Do you want to log out of this account and register a new donor or organization account?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                ref.read(authProvider.notifier).logout();
                                context.go('/register');
                              },
                              child: const Text('Register New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

                  // Delete Account
                  _buildSettingsTile(
                    icon: Icons.delete_outline_rounded,
                    iconBgColor: const Color(0xFFFFDAD6),
                    iconColor: const Color(0xFFBA1A1A),
                    title: 'Delete Account',
                    titleColor: const Color(0xFFBA1A1A),
                    subtitle: null,
                    onTap: _showDeleteAccountDialog,
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

                  // Logout
                  _buildSettingsTile(
                    icon: Icons.logout_rounded,
                    iconBgColor: const Color(0xFFF8E3E5),
                    iconColor: AppColors.primary,
                    title: 'Logout',
                    subtitle: null,
                    onTap: _showLogoutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    Color? titleColor,
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
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF24191A),
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

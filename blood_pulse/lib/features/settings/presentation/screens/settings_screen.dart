import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/locale_provider.dart';

/// Settings & Security Screen for BloodPulse.
/// Matches Stitch Screen `2247f788f26042908aa418ba2bfd621f`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsReceived = true;
  bool _urgentAlarms = true;
  bool _showPhoneNumber = true;
  bool _showNearbyLocation = true;
  bool _biometricLock = false;

  void _showChangePasswordDialog() {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Change Password',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            onPressed: () {
              final newPass = newPasswordCtrl.text;
              final confirmPass = confirmPasswordCtrl.text;
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
                return;
              }
              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
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
          'Are you sure you want to permanently delete your BloodPulse account and donor profile?\n\nThis action cannot be undone.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF4A4A4A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Log Out', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of BloodPulse?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final isBangla = currentLocale.languageCode == 'bn';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: CustomAppBar(
        title: 'Settings & Security',
        showLogo: false,
        showBackButton: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
      ),
      body: ResponsiveCenterWrapper(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Section 1: Notifications ──
            _buildSectionHeader('Notifications', Icons.notifications_active_outlined),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _notificationsReceived,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    title: const Text('Notification Received', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Receive alerts for comments, chats & match notifications', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    onChanged: (val) => setState(() => _notificationsReceived = val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile.adaptive(
                    value: _urgentAlarms,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    title: const Text('Emergency SOS Requests', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('High-priority push alarms when compatible blood is needed nearby', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    onChanged: (val) => setState(() => _urgentAlarms = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 2: Privacy & Donor Visibility ──
            _buildSectionHeader('Privacy & Proximity', Icons.privacy_tip_outlined),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _showPhoneNumber,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    title: const Text('Show Phone Number to Donors', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Allow verified requesters to call you directly during emergencies', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    onChanged: (val) => setState(() => _showPhoneNumber = val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile.adaptive(
                    value: _showNearbyLocation,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    title: const Text('Proximity Radius Visibility', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Appear in nearby donor radius without exposing your exact address', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    onChanged: (val) => setState(() => _showNearbyLocation = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 3: Account Security ──
            _buildSectionHeader('Security & Credentials', Icons.security_rounded),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFFEE9EB), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 18),
                    ),
                    title: const Text('Change Password', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Update your login password regularly', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile.adaptive(
                    value: _biometricLock,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    title: const Text('Biometric / Screen Lock Gate', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Require fingerprint / Face Unlock on app open', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    onChanged: (val) => setState(() => _biometricLock = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Section 4: Language & Regional ──
            _buildSectionHeader('Language & Region', Icons.language_rounded),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Interface Language',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          isBangla ? 'বর্তমানে বাংলা ভাষা নির্বাচিত' : 'Currently set to English',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'bn', label: Text('বাংলা', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {isBangla ? 'bn' : 'en'},
                    onSelectionChanged: (set) {
                      final lang = set.first;
                      ref.read(localeProvider.notifier).setLocale(Locale(lang));
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primary,
                      selectedForegroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Section 5: Account & Danger Actions ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                    ),
                    title: const Text('Delete Account', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle: const Text('Permanently erase account & donor profile', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: _showDeleteAccountDialog,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Color(0xFFFEE9EB), shape: BoxShape.circle),
                      child: const Icon(Icons.logout_rounded, color: AppColors.primary, size: 18),
                    ),
                    title: const Text('Log Out', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    subtitle: const Text('End your active BloodPulse session', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: _showLogoutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.6,
              color: Color(0xFF7A7A7A),
            ),
          ),
        ],
      ),
    );
  }
}

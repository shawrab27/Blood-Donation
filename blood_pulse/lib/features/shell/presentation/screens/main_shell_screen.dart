import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/profile_completion_gate.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/otp_provider.dart';

import '../../../feed/presentation/widgets/feed_view.dart';
import '../../../blood_hub/presentation/widgets/blood_hub_view.dart';
import '../../../communities/presentation/widgets/communities_view.dart';
import '../../../health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import '../../../profile/presentation/widgets/profile_view.dart';

/// The Main Responsive 5-Tab Navigation Shell of BloodPulse.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final List<Widget> tabs = [
      const _FeedTab(),
      const _BloodHubTab(),
      const _CommunitiesTab(),
      const _HealthHubTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      appBar: const BloodPulseAppBar(),
      body: tabs[_activeTabIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15), // ~0.06 opacity
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _activeTabIndex,
          onTap: (index) => setState(() => _activeTabIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.neutral,
          selectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.feed_outlined),
              activeIcon: const Icon(Icons.feed_rounded),
              label: l10n?.navFeed ?? 'Feed',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.water_drop_outlined),
              activeIcon: const Icon(Icons.water_drop_rounded),
              label: l10n?.navBloodHub ?? 'Blood Hub',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.groups_outlined),
              activeIcon: const Icon(Icons.groups_rounded),
              label: l10n?.navCommunities ?? 'Communities',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.health_and_safety_outlined),
              activeIcon: const Icon(Icons.health_and_safety_rounded),
              label: l10n?.navHealthHub ?? 'Health Hub',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: l10n?.navProfile ?? 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABS IMPLEMENTATION
// ─────────────────────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context) {
    return const FeedView();
  }
}



class _BloodHubTab extends StatelessWidget {
  const _BloodHubTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileCompletionGate(
      featureName: 'Blood Hub & Emergency Requests',
      child: BloodHubView(),
    );
  }
}

/// JIT (Just In Time) Verification Bottom Sheet Modal.
class _JitVerificationSheet extends ConsumerStatefulWidget {
  const _JitVerificationSheet();

  @override
  ConsumerState<_JitVerificationSheet> createState() => _JitVerificationSheetState();
}

class _JitVerificationSheetState extends ConsumerState<_JitVerificationSheet> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _otpSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Autopopulate user's primary phone if registered
    final user = ref.read(authProvider).user;
    if (user != null) {
      _phoneCtrl.text = user.primaryPhone;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onSendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter phone number');
      return;
    }

    setState(() => _error = null);
    await ref.read(otpStateProvider.notifier).sendOtp(primaryPhone: phone);
    setState(() => _otpSent = true);
  }

  void _onVerify() {
    final code = _codeCtrl.text.trim();
    final otpState = ref.read(otpStateProvider);

    if (code == otpState.correctCode || code == '1234') {
      // Success JIT verification
      ref.read(authProvider.notifier).setOtpVerified(true);
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Invalid verification code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpStateProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Verify Yourself',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'To request emergency blood, you must complete your security verification first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
          ),
          const SizedBox(height: 20),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),

          if (!_otpSent) ...[
            CustomInputField(
              controller: _phoneCtrl,
              hint: 'Primary Phone Number',
              prefixIcon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Send Verification Code',
              onPressed: _onSendOtp,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(10)),
              child: Text(
                '🔑 Debug PIN: ${otpState.correctCode} (or "1234")',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.tertiary, fontWeight: FontWeight.bold),
              ),
            ),
            CustomInputField(
              controller: _codeCtrl,
              hint: 'Enter 4-Digit Code',
              prefixIcon: Icons.lock_open_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Verify Code',
              onPressed: _onVerify,
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunitiesTab extends StatelessWidget {
  const _CommunitiesTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileCompletionGate(
      featureName: 'Community Donors & Clubs',
      child: CommunitiesView(),
    );
  }
}

class _HealthHubTab extends StatelessWidget {
  const _HealthHubTab();

  @override
  Widget build(BuildContext context) {
    return const HealthHubDashboardScreen();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileView();
  }
}

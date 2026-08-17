import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/otp_provider.dart';

import '../../../feed/presentation/widgets/feed_view.dart';
import '../../../blood_hub/presentation/widgets/blood_hub_view.dart';
import '../../../communities/presentation/widgets/communities_view.dart';
import '../../../health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import '../../../profile/presentation/widgets/profile_view.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';

/// The Main Responsive 5-Tab Navigation Shell of BloodPulse.
class ResponsiveAppShell extends ConsumerStatefulWidget {
  const ResponsiveAppShell({super.key});

  @override
  ConsumerState<ResponsiveAppShell> createState() => _ResponsiveAppShellState();
}

class _ResponsiveAppShellState extends ConsumerState<ResponsiveAppShell> {
  int _activeTabIndex = 0;

  Widget _buildBody(List<Widget> tabs) {
    // Wrap the tab content in our ResponsiveCenterWrapper
    // We pass 1200 as maxWidth because the tabs themselves might want to use Grids on wide screens.
    return ResponsiveCenterWrapper(
      maxWidth: 1200,
      child: tabs[_activeTabIndex],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      const _FeedTab(),
      const _BloodHubTab(),
      const _CommunitiesTab(),
      const _HealthHubTab(),
      const _ProfileTab(),
    ];

    final List<String> tabTitles = [
      'Feed',
      'Blood Hub',
      'Communities',
      'Health Hub',
      'Profile',
    ];

    final auth = ref.watch(authProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile Breakpoint
        if (constraints.maxWidth < 600) {
          return Scaffold(
            appBar: BloodPulseAppBar(
              subtitle: tabTitles[_activeTabIndex],
            ),
            body: _buildBody(tabs),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
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
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.feed_outlined), activeIcon: Icon(Icons.feed_rounded), label: 'Feed'),
                  BottomNavigationBarItem(icon: Icon(Icons.water_drop_outlined), activeIcon: Icon(Icons.water_drop_rounded), label: 'Blood Hub'),
                  BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups_rounded), label: 'Communities'),
                  BottomNavigationBarItem(icon: Icon(Icons.health_and_safety_outlined), activeIcon: Icon(Icons.health_and_safety_rounded), label: 'Health Hub'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
                ],
              ),
            ),
          );
        }

        // Tablet Breakpoint (Navigation Rail)
        if (constraints.maxWidth < 1000) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _activeTabIndex,
                  onDestinationSelected: (index) => setState(() => _activeTabIndex = index),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppColors.primary),
                  selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  unselectedLabelTextStyle: const TextStyle(color: AppColors.neutral, fontFamily: 'Inter'),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.feed_outlined), selectedIcon: Icon(Icons.feed_rounded), label: Text('Feed')),
                    NavigationRailDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop_rounded), label: Text('Blood Hub')),
                    NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: Text('Communities')),
                    NavigationRailDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety_rounded), label: Text('Health Hub')),
                    NavigationRailDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: Text('Profile')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Scaffold(
                    appBar: BloodPulseAppBar(subtitle: tabTitles[_activeTabIndex]),
                    body: _buildBody(tabs),
                  ),
                ),
              ],
            ),
          );
        }

        // Desktop Breakpoint (Sidebar / Navigation Drawer)
        return Scaffold(
          body: Row(
            children: [
              Container(
                width: 280,
                color: Colors.white,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // App Logo & Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.asset(
                            'assets/images/Blood Pulse logo.jpg',
                            height: 40,
                            width: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'BloodPulse',
                          style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Navigation Options
                    Expanded(
                      child: ListView.builder(
                        itemCount: tabTitles.length,
                        itemBuilder: (context, index) {
                          final isSelected = _activeTabIndex == index;
                          final icons = [
                            Icons.feed_outlined,
                            Icons.water_drop_outlined,
                            Icons.groups_outlined,
                            Icons.health_and_safety_outlined,
                            Icons.person_outline_rounded,
                          ];
                          final activeIcons = [
                            Icons.feed_rounded,
                            Icons.water_drop_rounded,
                            Icons.groups_rounded,
                            Icons.health_and_safety_rounded,
                            Icons.person_rounded,
                          ];
                          
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(50),
                                onTap: () => setState(() => _activeTabIndex = index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withAlpha(20) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? activeIcons[index] : icons[index],
                                        color: isSelected ? AppColors.primary : AppColors.neutral,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        tabTitles[index],
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? AppColors.primary : AppColors.neutral,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    // User Mini Profile Card
                    if (auth.user != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withAlpha(30),
                              child: Text(
                                auth.user!.fullName.isNotEmpty ? auth.user!.fullName[0] : '?',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.user!.fullName,
                                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    auth.user!.bloodGroup,
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Scaffold(
                  appBar: BloodPulseAppBar(subtitle: tabTitles[_activeTabIndex]),
                  body: _buildBody(tabs),
                ),
              ),
            ],
          ),
        );
      },
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
    return const BloodHubView();
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
    return const CommunitiesView();
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

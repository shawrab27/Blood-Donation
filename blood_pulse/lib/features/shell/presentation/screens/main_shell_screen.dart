// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/profile_completion_gate.dart';
import '../../../../core/access/access_guard.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../feed/presentation/providers/feed_provider.dart';

import '../../../feed/presentation/widgets/feed_view.dart';
import '../../../blood_hub/presentation/widgets/blood_hub_view.dart';
import '../../../blood_hub/presentation/screens/blood_hub_landing_screen.dart';
import '../../../communities/presentation/widgets/communities_view.dart';
import '../../../health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import '../../../profile/presentation/widgets/profile_view.dart';
import '../../../blood_hub/presentation/widgets/global_live_banner.dart';

import '../../../../widgets/pulseai_fab.dart';

/// The Main Responsive 5-Tab Navigation Shell of BloodPulse.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(shellTabProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTabIndex = ref.watch(shellTabProvider);
    final l10n = AppLocalizations.of(context);

    // Keep PageController synced if tab index changes externally
    if (_pageController.hasClients && _pageController.page?.round() != activeTabIndex) {
      _pageController.jumpToPage(activeTabIndex);
    }

    final List<Widget> tabs = [
      const _FeedTab(),
      const _BloodHubTab(),
      const _CommunitiesTab(),
      const _HealthHubTab(),
      const _ProfileTab(),
    ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isExpanded = screenWidth >= 840;

    void onTabSelected(int index) {
      final feature = _featureForIndex(index);
      AccessGuard.checkAndHandle(
        context: context,
        ref: ref,
        feature: feature,
        onAllowed: () {
          ref.read(shellTabProvider.notifier).state = index;
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
      );
    }

    final navigationRailDestinations = [
      NavigationRailDestination(
        icon: const Icon(Icons.feed_outlined),
        selectedIcon: const Icon(Icons.feed_rounded),
        label: Text(l10n?.navFeed ?? 'Feed'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.water_drop_outlined),
        selectedIcon: const Icon(Icons.water_drop_rounded),
        label: Text(l10n?.navBloodHub ?? 'Blood Hub'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups_rounded),
        label: Text(l10n?.navCommunities ?? 'Communities'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.health_and_safety_outlined),
        selectedIcon: const Icon(Icons.health_and_safety_rounded),
        label: Text(l10n?.navHealthHub ?? 'Health Hub'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded),
        label: Text(l10n?.navProfile ?? 'Profile'),
      ),
    ];

    Widget buildPageView({required double maxWidth}) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              final feature = _featureForIndex(index);
              AccessGuard.checkAndHandle(
                context: context,
                ref: ref,
                feature: feature,
                onAllowed: () {
                  ref.read(shellTabProvider.notifier).state = index;
                },
              );
            },
            children: tabs,
          ),
        ),
      );
    }

    return PopScope(
      key: const ValueKey('main_shell_pop_scope'),
      canPop: activeTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && activeTabIndex != 0) {
          // Return to Feed tab on Android back button before exiting app
          ref.read(shellTabProvider.notifier).state = 0;
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        appBar: const BloodPulseAppBar(),
        body: Column(
          children: [
            const GlobalLiveBanner(),
            Expanded(
              child: isExpanded
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: activeTabIndex,
                          onDestinationSelected: onTabSelected,
                          labelType: NavigationRailLabelType.all,
                          backgroundColor: AppColors.surface,
                          selectedIconTheme: const IconThemeData(color: AppColors.primary),
                          unselectedIconTheme: const IconThemeData(color: AppColors.neutral),
                          selectedLabelTextStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                          unselectedLabelTextStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.neutral,
                          ),
                          destinations: navigationRailDestinations,
                        ),
                        const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFEEEEEE)),
                        Expanded(
                          child: buildPageView(maxWidth: 1100.0),
                        ),
                      ],
                    )
                  : buildPageView(
                      maxWidth: screenWidth >= 600 ? 720.0 : double.infinity,
                    ),
            ),
          ],
        ),
        floatingActionButton: const PulseAIFAB(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: isExpanded
            ? null
            : Container(
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
                  currentIndex: activeTabIndex,
                  onTap: onTabSelected,
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
      ),
    );
  }

  AccessFeature _featureForIndex(int index) {
    switch (index) {
      case 0:
        return AccessFeature.feed;
      case 1:
        return AccessFeature.bloodHub;
      case 2:
        return AccessFeature.community;
      case 3:
        return AccessFeature.healthHub;
      case 4:
        return AccessFeature.profile;
      default:
        return AccessFeature.feed;
    }
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
      targetTabRoute: '/blood-hub',
      child: BloodHubLandingScreen(),
    );
  }
}

class _CommunitiesTab extends StatelessWidget {
  const _CommunitiesTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileCompletionGate(
      featureName: 'Communities & Donor Clubs',
      targetTabRoute: '/communities',
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
    return const ProfileCompletionGate(
      featureName: 'User Profile & Donation History',
      targetTabRoute: '/profile',
      child: ProfileView(),
    );
  }
}

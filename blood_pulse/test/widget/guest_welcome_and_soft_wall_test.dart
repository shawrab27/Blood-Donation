// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:blood_pulse/features/guest/presentation/screens/guest_welcome_screen.dart';
import 'package:blood_pulse/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/feed_view.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/guest_lock_card.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/auth/presentation/screens/splash_screen.dart';
import 'package:blood_pulse/features/auth/presentation/screens/language_selection_screen.dart';
import 'package:blood_pulse/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/science_of_blood_screen.dart';
import 'package:blood_pulse/features/health_hub/domain/providers/health_hub_provider.dart';
import 'package:blood_pulse/core/access/access_guard.dart';
import 'package:blood_pulse/core/access/registration_gate_popup.dart';
import 'package:blood_pulse/core/router_notifier.dart';
import 'package:blood_pulse/core/widgets/app_loader.dart';

class _TestFeedNotifier extends FeedNotifier {
  _TestFeedNotifier(List<FeedPostItem> initial) {
    state = initial;
  }
}

void main() {
  group('STEP 2: Guest Welcome Screen & Soft Wall Widget Tests', () {
    testWidgets('GuestWelcomeScreen renders layout matching Stitch screen 5e7b8264f0bc4398aae2a1020b193fb0', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: const MaterialApp(
            home: GuestWelcomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Header elements
      expect(find.text('Welcome, guest'), findsOneWidget);
      expect(find.text('Explore what BloodPulse does. Sign up to unlock everything.'), findsOneWidget);

      // 2. Nearby Donors Map Card
      expect(find.text('Nearby Donors'), findsOneWidget);
      expect(find.text('Locations are approximate for privacy.'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // 3. Quick Actions Card
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Become a Donor'), findsOneWidget);
      expect(find.text('Nearby Club'), findsOneWidget);
      expect(find.text('Express Emergency'), findsOneWidget);

      // 4. PulseAI Card
      expect(find.text('PulseAI'), findsOneWidget);
      expect(find.text('Try PulseAI'), findsOneWidget);

      // 5. Locked Features Card (Permanently removed per user specification)
      expect(find.text('Blood Hub, Chat & Profile'), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('C1: Guest taps on header notification bell and profile avatar show RegistrationGatePopup', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: const MaterialApp(
            home: GuestWelcomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Tap Header Notification Bell -> opens RegistrationGatePopup
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);
      expect(find.text('Complete your registration'), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 2. Tap Header Profile Avatar -> opens RegistrationGatePopup
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);
      expect(find.text('Complete your registration'), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);
    });

    testWidgets('Quick Actions and Locked Row trigger AccessGuard & RegistrationGatePopup', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: const MaterialApp(
            home: GuestWelcomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Tap Become a Donor -> opens RegistrationGatePopup
      await tester.tap(find.text('Become a Donor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);
      expect(find.text('Complete your registration'), findsOneWidget);
      expect(find.text('রেজিস্ট্রেশন সম্পূর্ণ করুন'), findsOneWidget);

      // Dismiss popup via close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 2. Tap Nearby Club -> opens RegistrationGatePopup
      await tester.tap(find.text('Nearby Club'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 3. Tap Express Emergency -> opens RegistrationGatePopup
      await tester.tap(find.text('Express Emergency'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 4. Tap Nearby Donors Map Card -> opens RegistrationGatePopup
      await tester.tap(find.text('Nearby Donors'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 5. Tap Explore button in Quick Actions -> opens RegistrationGatePopup
      await tester.tap(find.text('Explore'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('RegistrationGatePopup debounce prevents duplicate or stacked dialogs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const Text('Test Screen');
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Call show twice concurrently
      RegistrationGatePopup.show(capturedContext, isGuest: true);
      RegistrationGatePopup.show(capturedContext, isGuest: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert only 1 popup dialog is present in the tree
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismissing once completely removes the popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);
    });

    testWidgets('MainShellScreen enforces soft wall for guest across all 5 tabs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
            shellTabProvider.overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: MainShellScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initial tab is Feed (tab 0)
      expect(find.byType(FeedView), findsOneWidget);

      // Tap Blood Hub (tab 1) -> blocked by AccessGuard, popup shown
      await tester.tap(find.text('Blood Hub'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Still on Feed
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);

      // Tap Communities (tab 2) -> blocked by AccessGuard, popup shown
      await tester.tap(find.text('Communities'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);

      // Tap Health Hub (tab 3) -> allowed for guest!
      await tester.tap(find.text('Health Hub'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 3);

      // Tap Profile (tab 4) -> blocked by AccessGuard, popup shown
      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Still on Health Hub since Profile was blocked
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 3);
    });

    testWidgets('Guest in Feed attempting to interact triggers RegistrationGatePopup soft wall', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
            feedProvider.overrideWith((ref) => _TestFeedNotifier([
              const FeedPostItem(
                id: 'post_1',
                authorName: 'Test Author',
                timestamp: 'Just now',
                content: 'Test post',
              ),
            ])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: FeedView(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. GuestLockCard is rendered at top for guests; tapping Register now opens popup
      expect(find.byType(GuestLockCard), findsOneWidget);
      await tester.tap(find.text('Register now / রেজিস্ট্রেশন করুন').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 2. Guest attempts to react / like a post
      final likeButton = find.byIcon(Icons.favorite_border_rounded).first;
      await tester.tap(likeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);

      // 3. Guest attempts to comment on a post
      final commentButton = find.byIcon(Icons.chat_bubble_outline_rounded).first;
      await tester.tap(commentButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RegistrationGatePopup), findsNothing);
    });

    testWidgets('C3: Logged-in user opening /guest-welcome is redirected to /feed and back stack does not return to /guest-welcome', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          isGuestProvider.overrideWith((ref) => true),
          authProvider.overrideWith(
            () => AuthNotifier(initialState: const AuthState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routerNotifierProvider);
      final router = GoRouter(
        initialLocation: '/guest-welcome',
        refreshListenable: notifier,
        redirect: notifier.redirectLogic,
        routes: [
          GoRoute(
            path: '/guest-welcome',
            builder: (context, state) => const Scaffold(body: Text('GuestWelcomeRoute')),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('LoginRoute')),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(body: Text('FeedRoute')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Initially guest is on /guest-welcome
      expect(find.text('GuestWelcomeRoute'), findsOneWidget);

      // Simulate guest pushing /login and then completing authentication
      router.push('/login');
      await tester.pumpAndSettle();
      expect(find.text('LoginRoute'), findsOneWidget);

      container.read(authProvider.notifier).loginAsDemo();
      router.go('/feed');
      await tester.pumpAndSettle();

      // Now on /feed, isGuestProvider is cleared, and canPop is false (cannot go back to /guest-welcome)
      expect(find.text('FeedRoute'), findsOneWidget);
      expect(container.read(isGuestProvider), isFalse);
      expect(router.canPop(), isFalse);

      // Logged-in user attempting to open /guest-welcome directly is redirected to /feed
      router.go('/guest-welcome');
      await tester.pumpAndSettle();
      expect(find.text('FeedRoute'), findsOneWidget);
      expect(find.text('GuestWelcomeRoute'), findsNothing);
    });

    testWidgets('C6: Map loading, empty, offline/retry, and permission-denied states work cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Loading -> Empty state + Permission denied hint
      final completer = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: MaterialApp(
            home: GuestWelcomeScreen(
              locationResolver: () async => (
                center: const LatLng(23.6850, 90.3563),
                zoom: 7.0,
                statusMessage: 'Location denied — showing Bangladesh',
              ),
              mapDataFetcher: () => completer.future,
            ),
          ),
        ),
      );
      await tester.pump();
      // While completer is pending, AppLoader is shown
      expect(find.byType(AppLoader), findsOneWidget);

      completer.complete({'total_donors': 0, 'cells': <Map<String, dynamic>>[]});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Location denied — showing Bangladesh'), findsOneWidget);
      expect(find.text('No donors registered nearby yet'), findsOneWidget);
      expect(find.text('0 donors in your area'), findsOneWidget);

      // 2. Offline / Error state -> Retry recovers to populated state
      int calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: MaterialApp(
            home: GuestWelcomeScreen(
              key: const ValueKey('offline_test'),
              locationResolver: () async => (
                center: const LatLng(23.6850, 90.3563),
                zoom: 7.0,
                statusMessage: 'Location off — showing Bangladesh',
              ),
              mapDataFetcher: () async {
                calls++;
                if (calls == 1) {
                  throw Exception('Network offline');
                }
                return {
                  'total_donors': 5,
                  'cells': [
                    {
                      'geohash': 'wh0r',
                      'count': 5,
                      'latitude': 23.730469,
                      'longitude': 90.527344,
                    },
                  ],
                };
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Offline mode — map tiles cached locally'), findsOneWidget);
      expect(find.text('Retry connection'), findsOneWidget);

      await tester.tap(find.text('Retry connection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('5 donors in your area'), findsOneWidget);
      expect(find.text('Offline mode — map tiles cached locally'), findsNothing);
    });

    testWidgets('C6: GuestWelcomeScreen & RegistrationGatePopup render at 320x568, 360x800, 412x915 at text scale 1.0 and 1.3 without overflow', (tester) async {
      const sizes = [
        Size(320, 568),
        Size(360, 800),
        Size(412, 915),
      ];
      const scales = [1.0, 1.3];

      addTearDown(tester.view.resetPhysicalSize);

      for (final size in sizes) {
        for (final scale in scales) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                isGuestProvider.overrideWith((ref) => true),
                authProvider.overrideWith(
                  () => AuthNotifier(initialState: const AuthState()),
                ),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: GuestWelcomeScreen(
                    key: ValueKey('gw_${size.width}_${size.height}_$scale'),
                    locationResolver: () async => (
                      center: const LatLng(23.6850, 90.3563),
                      zoom: 7.0,
                      statusMessage: 'Location off — showing Bangladesh',
                    ),
                    mapDataFetcher: () async => {
                      'total_donors': 3,
                      'cells': [
                        {
                          'geohash': 'wh0r',
                          'count': 3,
                          'latitude': 23.730469,
                          'longitude': 90.527344,
                        },
                      ],
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'Overflow on GuestWelcomeScreen at $size scale $scale');

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: RegistrationGatePopup(
                    key: ValueKey('rg_${size.width}_${size.height}_$scale'),
                    isGuest: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'Overflow on RegistrationGatePopup at $size scale $scale');
        }
      }
    });

    testWidgets('C2 & C6: Smoke test — Splash, Language, Onboarding, 5-tab navbar, Feed, and Health Hub render without raw error dialogs for guest', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. LanguageSelectionScreen
      final langRouter = GoRouter(
        initialLocation: '/language',
        routes: [
          GoRoute(path: '/language', builder: (_, __) => const LanguageSelectionScreen()),
          GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LoginTarget'))),
          GoRoute(path: '/feed', builder: (_, __) => const Scaffold(body: Text('FeedTarget'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('smoke_lang_onboarding'),
          child: MaterialApp.router(routerConfig: langRouter),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // 2. OnboardingScreen
      langRouter.go('/onboarding');
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // 3. SplashScreen
      final splashRouter = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
          GoRoute(path: '/onboarding', builder: (_, __) => const Scaffold(body: Text('OnboardingTarget'))),
          GoRoute(path: '/feed', builder: (_, __) => const Scaffold(body: Text('FeedTarget'))),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('LoginTarget'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('smoke_splash'),
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: MaterialApp.router(routerConfig: splashRouter),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 4. HealthHubDashboardScreen & ScienceOfBloodScreen when API fails (friendly fallback, no raw error)
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('smoke_science'),
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
            scienceArticlesProvider.overrideWith((ref) async {
              throw Exception('401 Unauthorized');
            }),
          ],
          child: const MaterialApp(home: ScienceOfBloodScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Unable to load articles'), findsNothing);
      expect(find.text('The Four Components of Blood'), findsOneWidget);

      // 5. HealthHubDashboardScreen
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('smoke_health_hub'),
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: const MaterialApp(home: HealthHubDashboardScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}

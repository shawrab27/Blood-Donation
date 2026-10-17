// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/personal_emergency_screen.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/notifications/domain/providers/notification_provider.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';

class FakeNotificationCountNotifier extends NotificationCountNotifier {
  FakeNotificationCountNotifier() : super(enablePolling: false);
}

class FakeAuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      user: UserProfile(
        fullName: 'Test User',
        email: 'test@example.com',
        primaryPhone: '+8801712345678',
        age: 26,
        gender: 'Male',
        bloodGroup: 'A+',
        category: 'civilian',
        categoryDetails: {},
        neverDonated: false,
        totalBagsDonated: 3,
        isProfileComplete: true,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Anomaly #24: Back Button Navigation & Form Protection Tests', () {
    testWidgets('1. Back closes open dialog first without altering tab state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthenticatedAuthNotifier()),
          notificationCountProvider.overrideWith((ref) => FakeNotificationCountNotifier()),
          shellTabProvider.overrideWith((ref) => 1), // Tab 1: Blood Hub
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MainShellScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(shellTabProvider), 1);

      // Open a dialog
      final BuildContext context = tester.element(find.byType(MainShellScreen));
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Test Dialog Open')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Test Dialog Open'), findsOneWidget);

      // Trigger back button -> closes dialog
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Test Dialog Open'), findsNothing);
      expect(container.read(shellTabProvider), 1);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('2. On non-Feed root tab, back navigates to Feed (tab 0)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthenticatedAuthNotifier()),
          notificationCountProvider.overrideWith((ref) => FakeNotificationCountNotifier()),
          shellTabProvider.overrideWith((ref) => 2), // Tab 2: Communities
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MainShellScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(shellTabProvider), 2);

      // Press back on Tab 2 -> navigates to Feed tab (0)
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(shellTabProvider), 0);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('3. On Feed tab, double-back within 2s exits; single back shows snackbar', (tester) async {
      int systemPopCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'SystemNavigator.pop') {
          systemPopCalls++;
        }
        return null;
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthenticatedAuthNotifier()),
          notificationCountProvider.overrideWith((ref) => FakeNotificationCountNotifier()),
          shellTabProvider.overrideWith((ref) => 0), // Tab 0: Feed
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ScaffoldMessenger(child: MainShellScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // First back press -> shows snackbar
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(systemPopCalls, 0);

      // Second back press within 2s -> calls SystemNavigator.pop()
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      expect(systemPopCalls, 1);

      // Let snackbar timer finish cleanly
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('4. Form with unsaved input prompts confirm discard dialog on back', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => FakeAuthenticatedAuthNotifier()),
          notificationCountProvider.overrideWith((ref) => FakeNotificationCountNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PersonalEmergencyScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Select blood group chip to dirty the form
      final chip = find.text('A+');
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Try pressing back
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));

      // Confirmation dialog should be shown
      expect(find.text('Discard unsaved request?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Tap "Keep Editing" -> dialog closes, form stays
      await tester.tap(find.text('Keep Editing'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Discard unsaved request?'), findsNothing);
      expect(find.byType(PersonalEmergencyScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('5. Nested navigator / pushed screen pops to parent on back', (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('Root Screen')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Push child route without transition delay
      navKey.currentState!.push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const Scaffold(body: Text('Child Screen')),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      await tester.pump();

      expect(find.text('Child Screen'), findsOneWidget);

      // Back action on navigator pops child screen
      navKey.currentState!.pop();
      await tester.pump();

      // Popped back to Root Screen
      expect(find.text('Child Screen'), findsNothing);
      expect(find.text('Root Screen'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6. Flutter web / browser back pops history without crashing', (tester) async {
      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (_, __) => const NoTransitionPage(child: Scaffold(body: Text('Feed Screen'))),
          ),
          GoRoute(
            path: '/details',
            pageBuilder: (_, __) => const NoTransitionPage(child: Scaffold(body: Text('Details Screen'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Feed Screen'), findsOneWidget);

      // Navigate to details
      router.push('/details');
      await tester.pump();

      expect(find.text('Details Screen'), findsOneWidget);

      // Web/Browser back pop
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pump();

      expect(find.text('Details Screen'), findsNothing);
      expect(find.text('Feed Screen'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}

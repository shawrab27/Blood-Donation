// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';
import 'package:blood_pulse/features/shell/presentation/screens/main_shell_screen.dart';

import 'package:blood_pulse/features/notifications/domain/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUser = UserProfile(
    fullName: 'Back Test User',
    email: 'backtest@example.com',
    primaryPhone: '+8801712345678',
    age: 26,
    gender: 'Male',
    bloodGroup: 'O+',
    category: 'civilian',
    categoryDetails: {},
    neverDonated: false,
    totalBagsDonated: 1,
    isOtpVerified: true,
    isProfileComplete: true,
    isEmailVerified: true,
  );

  group('Part 4: Android Back Button Tests', () {
    testWidgets('1. Shell: Non-zero tab redirects to Feed on back press, then shows exit hint', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => AuthNotifier(
                initialState: const AuthState(
                  status: AuthStatus.authenticated,
                  user: testUser,
                ),
              ),
            ),
            shellTabProvider.overrideWith((ref) => 1), // Start on Blood Hub (tab 1)
            notificationCountProvider.overrideWith(
              (ref) => NotificationCountNotifier(enablePolling: false),
            ),
          ],
          child: const MaterialApp(
            home: MainShellScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Current tab is Blood Hub (1)
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 1);

      // Trigger back button on PopScope
      final popScopeFinder = find.byKey(const ValueKey('main_shell_pop_scope'));
      expect(popScopeFinder, findsOneWidget);

      final PopScope popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);

      // Simulate Android back press invocation
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pump(const Duration(milliseconds: 350));

      // Verified: Redirects to Feed tab (0)
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);

      // Now on Feed tab: fetch updated PopScope and simulate back press
      final PopScope feedPopScope = tester.widget<PopScope>(popScopeFinder);
      feedPopScope.onPopInvokedWithResult?.call(false, null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verified: Shows exit hint toast
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Press back again to exit'), findsOneWidget);

      // Advance clock so the SnackBar auto-dismiss timer completes cleanly
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('2. Nested Flow 1: Open dialog/modal is dismissed first by back press', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => const AlertDialog(
                      title: Text('Confirmation Dialog'),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmation Dialog'), findsOneWidget);

      // Simulate back press via handlePopRoute
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Verified: Dialog is dismissed, underlying screen remains
      expect(find.text('Confirmation Dialog'), findsNothing);
      expect(find.text('Open Dialog'), findsOneWidget);
    });

    testWidgets('3. Nested Flow 2: Nested pushed route is popped back to parent screen', (tester) async {
      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/details'),
                  child: const Text('Go to Details'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/details',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Nested Details Screen')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Manual Back'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Go to Details'), findsOneWidget);

      // Navigate to nested route
      await tester.tap(find.text('Go to Details'));
      await tester.pumpAndSettle();

      expect(find.text('Nested Details Screen'), findsOneWidget);

      // Press Android back button via system handlePopRoute
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Verified: Popped back to parent Feed screen
      expect(find.text('Nested Details Screen'), findsNothing);
      expect(find.text('Go to Details'), findsOneWidget);
    });

    testWidgets('4. Nested Flow 3: Post-login/logout stack clearing prevents back navigation to auth screen', (tester) async {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.go('/feed'), // Clear stack on login transition
                child: const Text('Sign In Action'),
              ),
            ),
          ),
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(
              body: Text('Main Feed Shell'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Sign In Action'), findsOneWidget);

      // Perform sign in with context.go('/feed')
      await tester.tap(find.text('Sign In Action'));
      await tester.pumpAndSettle();

      expect(find.text('Main Feed Shell'), findsOneWidget);

      // Attempt back navigation
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      final handled = await widgetsAppState.didPopRoute();

      // Router stack has no prior routes (canPop is false)
      expect(handled, isFalse, reason: 'Stack was cleared so back cannot pop back to login screen');
      expect(find.text('Sign In Action'), findsNothing);
      expect(find.text('Main Feed Shell'), findsOneWidget);
    });
  });
}

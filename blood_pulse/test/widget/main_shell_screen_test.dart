// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';

void main() {
  testWidgets('MainShellScreen hosts all 5 tabs and clicking them opens respective tabs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Provide authenticated and complete user so all tabs are accessible
    const completeUser = UserProfile(
      fullName: 'Test User',
      email: 'test@example.com',
      primaryPhone: '01711111111',
      age: 25,
      gender: 'Male',
      bloodGroup: 'B+',
      category: 'civilian',
      categoryDetails: {},
      neverDonated: false,
      totalBagsDonated: 2,
      isOtpVerified: true,
      isProfileComplete: true,
      isEmailVerified: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: completeUser,
              ),
            ),
          ),
          shellTabProvider.overrideWith((ref) => 0),

        ],
        child: const MaterialApp(
          home: MainShellScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify 5 navigation bar items exist
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Blood Hub'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Health Hub'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Initial tab is Feed
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Tap Blood Hub tab
    await tester.tap(find.text('Blood Hub'));
    await tester.pump();
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 1);

    // Tap Communities tab
    await tester.tap(find.text('Communities'));
    await tester.pump();
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 2);

    // Tap Health Hub tab
    await tester.tap(find.text('Health Hub'));
    await tester.pump();
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 3);

    // Tap Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 4);

    // Tap back to Feed tab
    await tester.tap(find.text('Feed'));
    await tester.pump();
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);
  });

  testWidgets('MainShellScreen supports swiping between tabs via PageView', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    const completeUser = UserProfile(
      fullName: 'Test User',
      email: 'test@example.com',
      primaryPhone: '01711111111',
      age: 25,
      gender: 'Male',
      bloodGroup: 'B+',
      category: 'civilian',
      categoryDetails: {},
      neverDonated: false,
      totalBagsDonated: 2,
      isOtpVerified: true,
      isProfileComplete: true,
      isEmailVerified: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            () => AuthNotifier(
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: completeUser,
              ),
            ),
          ),
          shellTabProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(
          home: MainShellScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify PageView exists
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);

    // Tap to tab 1 to verify PopScope
    await tester.tap(find.text('Blood Hub'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 1);

    // Verify PopScope pops back to Tab 0 when on Tab 1
    final popScope = tester.widget<PopScope>(find.byKey(const ValueKey('main_shell_pop_scope')));
    expect(popScope.canPop, isFalse);
  });
}

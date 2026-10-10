// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/core/widgets/profile_completion_gate.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';

void main() {
  group('ProfileCompletionGate Tests', () {
    testWidgets('Completed profile renders child directly without lock card', (tester) async {
      const user = UserProfile(
        fullName: 'Completed User',
        email: 'user@test.com',
        primaryPhone: '01811111111',
        age: 25,
        gender: 'male',
        bloodGroup: 'O+',
        category: 'civilian',
        categoryDetails: {},
        neverDonated: false,
        totalBagsDonated: 1,
        isProfileComplete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => AuthNotifierMock(
              const AuthState(status: AuthStatus.authenticated, user: user),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileCompletionGate(
                featureName: 'Blood Hub',
                targetTabRoute: '/blood-hub',
                child: Text('CHILD CONTENT UNLOCKED'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CHILD CONTENT UNLOCKED'), findsOneWidget);
      expect(find.text('সম্পূর্ণ করুন আপনার প্রোফাইল'), findsNothing);
    });

    for (final tab in [
      {'name': 'Blood Hub', 'route': '/blood-hub'},
      {'name': 'Communities', 'route': '/communities'},
      {'name': 'Profile', 'route': '/profile'},
    ]) {
      testWidgets('Incomplete profile on ${tab['name']} shows lock card and navigates to /register with prefill', (tester) async {
        const incompleteUser = UserProfile(
          fullName: 'Google User',
          email: 'google@test.com',
          primaryPhone: '',
          age: 0,
          gender: '',
          bloodGroup: '',
          category: 'civilian',
          categoryDetails: {},
          neverDonated: true,
          totalBagsDonated: 0,
          isProfileComplete: false,
          missingFields: ['blood_group', 'district', 'phone_number'],
          authProvider: 'google',
        );

        Map<String, dynamic>? receivedExtra;

        final router = GoRouter(
          initialLocation: tab['route']!,
          routes: [
            GoRoute(
              path: tab['route']!,
              builder: (_, __) => Scaffold(
                body: ProfileCompletionGate(
                  featureName: tab['name']!,
                  targetTabRoute: tab['route'],
                  child: const Text('TAB PROTECTED CONTENT'),
                ),
              ),
            ),
            GoRoute(
              path: '/register',
              builder: (_, state) {
                receivedExtra = state.extra as Map<String, dynamic>?;
                return const Scaffold(body: Text('REGISTER SCREEN'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => AuthNotifierMock(
                const AuthState(status: AuthStatus.authenticated, user: incompleteUser),
              )),
            ],
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Lock card is rendered with specific tab feature name
        expect(find.text('সম্পূর্ণ করুন আপনার প্রোফাইল'), findsOneWidget);
        expect(find.text('Complete Your Profile to Unlock ${tab['name']}'), findsOneWidget);

        // Tap the capsule action button
        final button = find.text('সম্পূর্ণ করুন / Complete Profile');
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();

        // Assert navigated to /register with prefill & return route
        expect(find.text('REGISTER SCREEN'), findsOneWidget);
        expect(receivedExtra, isNotNull);
        expect(receivedExtra!['targetRoute'], equals(tab['route']));
        expect(receivedExtra!['prefillName'], equals('Google User'));
        expect(receivedExtra!['prefillEmail'], equals('google@test.com'));
        expect(receivedExtra!['isGoogleUser'], isTrue);
      });
    }
  });
}

class AuthNotifierMock extends AuthNotifier {
  final AuthState _initial;
  AuthNotifierMock(this._initial);

  @override
  AuthState build() => _initial;
}

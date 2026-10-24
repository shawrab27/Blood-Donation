// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/core/access/registration_gate_popup.dart';

void main() {
  group('Auth Gating Bottom Sheet Widget Tests (G2)', () {
    late GoRouter testRouter;
    late bool navigatedToRegister;

    Widget createTestApp({required bool isGuest}) {
      navigatedToRegister = false;
      testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('trigger_gate_button'),
                  onPressed: () => RegistrationGatePopup.show(context, isGuest: isGuest),
                  child: const Text('Trigger Gate'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) {
              navigatedToRegister = true;
              return const Scaffold(body: Text('Screen: Registration'));
            },
          ),
        ],
      );

      return ProviderScope(
        child: MaterialApp.router(
          routerConfig: testRouter,
        ),
      );
    }

    testWidgets('Displays bottom sheet with correct title and subtitle for guest', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(createTestApp(isGuest: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_gate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Complete your account to continue'), findsOneWidget);
      expect(
        find.text('Declare your blood group and details to react, comment, post, or request blood.'),
        findsOneWidget,
      );
      expect(find.text('Register Now'), findsOneWidget);

      // Verify tap on Register Now navigates to /register
      await tester.tap(find.byKey(const Key('registration_gate_button')));
      await tester.pumpAndSettle();

      expect(navigatedToRegister, isTrue);
      expect(find.text('Screen: Registration'), findsOneWidget);
    });

    testWidgets('Displays Complete Registration for incomplete logged-in user without overflowing at 320dp', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpWidget(createTestApp(isGuest: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('trigger_gate_button')));
      await tester.pumpAndSettle();

      expect(find.text('Complete your account to continue'), findsOneWidget);
      expect(find.text('Complete Registration'), findsOneWidget);

      // Verify no overflow
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('registration_gate_button')));
      await tester.pumpAndSettle();

      expect(navigatedToRegister, isTrue);
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/features/auth/presentation/screens/registration_screen.dart';
import 'package:blood_pulse/features/blood_request/presentation/screens/identity_verification_screen.dart';
import 'package:blood_pulse/features/auth/presentation/screens/language_selection_screen.dart';

void main() {
  group('Step 1 Screens Responsive Overflow Tests (320x568, 360x800, 412x915 @ textScale 1.3)', () {
    final sizes = [
      const Size(320, 568),
      const Size(360, 800),
      const Size(412, 915),
    ];

    testWidgets('RegistrationScreen scales without overflow across target viewports', (tester) async {
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const MaterialApp(
                home: RegistrationScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'RegistrationScreen overflowed at $size (scale 1.3)');
      }
    });

    testWidgets('IdentityVerificationScreen scales without overflow across target viewports', (tester) async {
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const MaterialApp(
                home: IdentityVerificationScreen(
                  patientName: 'Test Patient',
                  bloodGroup: 'B+',
                  urgencyLevel: 'Critical',
                  hospitalLocation: 'Dhaka Medical',
                  contactNumber: '01711111111',
                  email: 'test@example.com',
                  autoSend: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'IdentityVerificationScreen overflowed at $size (scale 1.3)');
      }
    });

    testWidgets('LanguageSelectionScreen scales without overflow across target viewports', (tester) async {
      final router = GoRouter(
        initialLocation: '/language',
        routes: [
          GoRoute(path: '/language', builder: (_, __) => const LanguageSelectionScreen()),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login'))),
        ],
      );

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              publicStatsProvider.overrideWith((ref) async => {
                'registered_donors': 50,
                'districts_covered': 12,
              }),
            ],
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: MaterialApp.router(
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'LanguageSelectionScreen overflowed at $size (scale 1.3)');
      }
    });
  });
}

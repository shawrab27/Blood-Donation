// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/features/auth/presentation/screens/language_selection_screen.dart';

void main() {
  GoRouter createTestRouter() {
    return GoRouter(
      initialLocation: '/language',
      routes: [
        GoRoute(
          path: '/language',
          builder: (context, state) => const LanguageSelectionScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('Login Screen')),
        ),
      ],
    );
  }

  testWidgets('LanguageSelectionScreen shows truthful fallback when stats < 10 or null', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicStatsProvider.overrideWith((ref) async => {
            'registered_donors': 5,
            'districts_covered': 2,
          }),
        ],
        child: MaterialApp.router(
          routerConfig: createTestRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify fake claim is completely absent
    expect(find.textContaining('2M+'), findsNothing);
    expect(find.textContaining('২০ লাখ'), findsNothing);

    // Default English fallback text
    expect(find.text('A non-profit blood donation network for Bangladesh'), findsOneWidget);
  });

  testWidgets('LanguageSelectionScreen shows live formatted stats when donors >= 10', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicStatsProvider.overrideWith((ref) async => {
            'registered_donors': 42,
            'districts_covered': 8,
          }),
        ],
        child: MaterialApp.router(
          routerConfig: createTestRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // English live stats
    expect(find.text('42 donors across 8 districts'), findsOneWidget);

    // Switch to Bangla
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    // Bangla live stats with Bengali numerals
    expect(find.text('৮টি জেলায় ৪২ জন রক্তদাতা'), findsOneWidget);
    expect(find.textContaining('2M+'), findsNothing);
    expect(find.textContaining('২০ লাখ'), findsNothing);
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/features/splash/splash_screen.dart';
import 'package:blood_pulse/features/auth/presentation/screens/language_selection_screen.dart';
import 'package:blood_pulse/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';

void main() {
  group('Onboarding, Language Selection, and Splash Smoke Tests', () {
    testWidgets('SplashScreen renders logo and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SplashScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains('Blood Pulse') == true,
        ),
        findsWidgets,
      );
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('LanguageSelectionScreen renders English and Bangla language options', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/language',
        routes: [
          GoRoute(path: '/language', builder: (_, __) => const LanguageSelectionScreen()),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and options render
      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Verify toggling to Bangla works smoothly
      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();

      // Verify toggling back to English
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
    });

    testWidgets('OnboardingScreen renders all 3 slides in sequence without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
          GoRoute(path: '/language', builder: (_, __) => const Scaffold(body: Text('Language Screen'))),
          GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ── Slide 1: Donate Blood ──
      expect(find.text('Donate Blood'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(
        find.text('Empower life through voluntary donation. Your single contribution can save up to three lives in emergency care.'),
        findsOneWidget,
      );

      // Tap Next to advance to Slide 2
      final nextButton = find.text('Next');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // ── Slide 2: Save Lives ──
      expect(find.text('Save Lives'), findsOneWidget);
      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      expect(
        find.text('Every drop matters. Connect instantly with local hospitals and patients facing critical emergencies to provide life-saving transfusions.'),
        findsOneWidget,
      );

      // Tap Next to advance to Slide 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // ── Slide 3: Get Connected in Community ──
      expect(find.text('Get Connected in Community'), findsOneWidget);
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });
}

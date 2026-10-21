// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/localization/locale_provider.dart';
import 'package:blood_pulse/core/widgets/language_toggle_button.dart';
import 'package:blood_pulse/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _BanglaLocaleNotifier extends LocaleNotifier {
  _BanglaLocaleNotifier() {
    state = const Locale('bn');
  }
}

void main() {
  group('H-02 Navigation & Localization Regression Tests', () {
    testWidgets('LanguageToggleButton toggles between EN and BN', (tester) async {
      Locale? currentLocale;

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              currentLocale = ref.watch(localeProvider);
              return MaterialApp(
                locale: currentLocale,
                home: const Scaffold(
                  body: Center(child: LanguageToggleButton()),
                ),
              );
            },
          ),
        ),
      );

      expect(find.byType(LanguageToggleButton), findsOneWidget);
      expect(currentLocale?.languageCode, equals('en'));

      // Tap toggle button to switch to Bangla
      await tester.tap(find.byType(LanguageToggleButton));
      await tester.pumpAndSettle();

      expect(currentLocale?.languageCode, equals('bn'));

      // Tap toggle button again to switch back to English
      await tester.tap(find.byType(LanguageToggleButton));
      await tester.pumpAndSettle();

      expect(currentLocale?.languageCode, equals('en'));
    });

    testWidgets('OnboardingScreen navigates forward and PopScope intercepts back to step 1', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(initialStep: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Step 1 is rendered
      expect(find.text('Donate Blood'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next -> Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Save Lives'), findsOneWidget);

      // Simulate Android physical back button (didPopRoute)
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pumpAndSettle();

      // PopScope intercepted and navigated back to Step 1 instead of exiting
      expect(find.text('Donate Blood'), findsOneWidget);
    });

    testWidgets('OnboardingScreen shows Bangla text when locale is BN', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => _BanglaLocaleNotifier()),
          ],
          child: const MaterialApp(
            locale: Locale('bn'),
            home: OnboardingScreen(initialStep: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Step 1 Bangla text
      expect(find.text('রক্তদান করুন'), findsOneWidget);
      expect(find.text('পরবর্তী'), findsOneWidget);
    });
  });
}

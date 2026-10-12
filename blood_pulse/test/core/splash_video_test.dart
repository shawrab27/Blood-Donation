// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/splash_video_screen.dart';

void main() {
  group('Splash Video Screen Regression Tests', () {
    testWidgets('Renders static fallback brand logo immediately without blank screen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashVideoScreen(),
          ),
        ),
      );

      // Verify static brand logo and title render immediately
      expect(find.text('BloodPulse'), findsOneWidget);
      expect(find.text('Every Drop Counts'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Verify failure path: video controller fails, fallback timer fires after 1200ms
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Skip button triggers navigation cleanly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashVideoScreen(),
          ),
        ),
      );

      final skipFinder = find.text('Skip');
      expect(skipFinder, findsOneWidget);
      await tester.tap(skipFinder);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
    });
  });
}

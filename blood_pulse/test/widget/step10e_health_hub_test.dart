// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_calculators_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/common/health_accessory_contextual_card.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/dashboard/health_hub_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Step 10E: Health Hub & Accessories Tab Isolation', () {
    testWidgets('Dashboard renders clean Stitch layout with 8 tools and zero clutter cards', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HealthHubDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and subtitle
      expect(find.text('Health Hub'), findsOneWidget);
      expect(find.text('Your wellness overview and clinical insights.'), findsOneWidget);
      expect(find.text('Tools & Insights'), findsOneWidget);

      // Verify all 8 tool cards from Stitch screen
      expect(find.text('AI Analysis'), findsOneWidget);
      expect(find.text('Health & Blood Accessories'), findsOneWidget);
      expect(find.text('Blood Science'), findsOneWidget);
      expect(find.text('Compatibility'), findsOneWidget);
      expect(find.text('Donation Guide'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Recovery & Aftercare'), findsOneWidget);
      expect(find.text('Calculators'), findsOneWidget);

      // Verify clutter has been completely removed
      expect(find.byType(HealthHubStatusCard), findsNothing);
      expect(find.byType(HealthAccessoryContextualCard), findsNothing);
    });

    testWidgets('Calculators sub-screen has ZERO HealthAccessoryContextualCard (tab isolation)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HealthCalculatorsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero accessory cards in calculators sub-screen
      expect(find.byType(HealthAccessoryContextualCard), findsNothing);
    });

    testWidgets('HealthHubDashboardScreen passes responsive sweep at 4 viewport sizes with textScale 1.3', (tester) async {
      final viewports = [
        const Size(320, 640),
        const Size(360, 800),
        const Size(412, 915),
        const Size(600, 960),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: const Scaffold(
                  body: HealthHubDashboardScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HealthHubDashboardScreen), findsOneWidget);
      }
    });
  });
}

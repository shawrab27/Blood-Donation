// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/health_hub/presentation/providers/hydration_provider.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_calculators_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/recovery_aftercare_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/ai_report/ai_report_error_banner.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/calculators/hydration_tracker_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 10F - F1: Health Hub Overflow, Unified Hydration & AI Scanner', () {
    testWidgets('HydrationProvider acts as unified source of truth with 2500ml target', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(hydrationProvider.notifier);
      final initialState = container.read(hydrationProvider);

      expect(initialState.targetGlasses, equals(10));
      expect(initialState.targetMl, equals(2500));

      await notifier.addGlass();
      expect(container.read(hydrationProvider).glasses, equals(initialState.glasses + 1));

      await notifier.removeGlass();
      expect(container.read(hydrationProvider).glasses, equals(initialState.glasses));
    });

    testWidgets('AiReportErrorBanner displays friendly message and medical disclaimer for non-reports', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiReportErrorBanner(
              errorMessage: 'incorrect image or not a blood report',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("This doesn't look like a blood report"), findsOneWidget);
      expect(find.textContaining('Medical Disclaimer'), findsOneWidget);
      expect(find.textContaining('Validation Warning'), findsNothing);
    });

    testWidgets('HydrationTrackerCard renders without overflow on ultra-narrow 320x640 with textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: HydrationTrackerCard(
                glasses: 5,
                onAddGlass: () {},
                onRemoveGlass: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HydrationTrackerCard), findsOneWidget);
      expect(find.textContaining('2,500 ml target'), findsOneWidget);
    });

    testWidgets('RecoveryAftercareScreen passes responsive sweep at 4 viewport sizes with textScale 1.3', (tester) async {
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
                  body: RecoveryAftercareScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Biological Recovery Timeline'), findsOneWidget);
      }
    });

    testWidgets('HealthCalculatorsScreen passes responsive sweep at 4 viewport sizes with textScale 1.3', (tester) async {
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
                  body: HealthCalculatorsScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HealthCalculatorsScreen), findsOneWidget);
      }
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/guest/presentation/screens/guest_welcome_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/recovery_aftercare_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/science_of_blood_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/donation_guide_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/blood_compatibility_screen.dart';
import 'package:blood_pulse/core/theme/app_spacing.dart';

void main() {
  const List<Size> testSizes = [
    Size(320, 640),
    Size(360, 800),
    Size(412, 915),
    Size(600, 960),
  ];

  const List<double> textScales = [1.0, 1.3];

  group('Overflow Sweep Tests (Zero RenderFlex Overflow Guarantee)', () {
    for (final size in testSizes) {
      for (final textScale in textScales) {
        testWidgets(
          'RecoveryAftercareScreen renders without overflow at ${size.width}x${size.height} (scale: $textScale)',
          (WidgetTester tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const RecoveryAftercareScreen(),
                  ),
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'ScienceOfBloodScreen renders without overflow at ${size.width}x${size.height} (scale: $textScale)',
          (WidgetTester tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const ScienceOfBloodScreen(),
                  ),
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'DonationGuideScreen renders without overflow at ${size.width}x${size.height} (scale: $textScale)',
          (WidgetTester tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const DonationGuideScreen(),
                  ),
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'BloodCompatibilityScreen renders without overflow at ${size.width}x${size.height} (scale: $textScale)',
          (WidgetTester tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const BloodCompatibilityScreen(),
                  ),
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('Responsive Foundation Component Tests', () {
    testWidgets('ResponsiveRow switches to column on narrow viewport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ResponsiveRow(
                breakpoint: 340,
                children: const [
                  Text('Item 1'),
                  Text('Item 2'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('AppButton enforces min 48dp touch target and fits text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              onPressed: () {},
              label: 'Very Long Action Button Label That Must Not Overflow',
            ),
          ),
        ),
      );
      final buttonSize = tester.getSize(find.byType(AppButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
      expect(tester.takeException(), isNull);
    });
  });
}

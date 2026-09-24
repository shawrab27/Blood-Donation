import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/blood_hub_search_screen.dart';

void main() {
  group('Responsive Widget Tests (No Overflow)', () {
    final sizes = [
      const Size(320, 568), // Small phone (iPhone SE)
      const Size(390, 844), // Regular phone
      const Size(600, 960), // Small tablet
    ];

    testWidgets('HealthHubDashboardScreen scales without render overflow', (WidgetTester tester) async {
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(
            home: HealthHubDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow exception at $size');
      }
    });

    testWidgets('BloodHubSearchScreen scales without render overflow', (WidgetTester tester) async {
      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(
            home: BloodHubSearchScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow exception at $size');
      }
    });
  });
}

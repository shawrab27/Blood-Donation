// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/health_hub/presentation/screens/health_hub_dashboard_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_calculators_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/common/health_accessory_contextual_card.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/dashboard/health_hub_status_card.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(ProfileModel? initial) : super() {
    state = AsyncValue.data(initial);
  }
}

void main() {
  group('Step 10E: Health Hub & Accessories Tab Isolation', () {
    testWidgets('Dashboard renders StatusCard and exactly ONE HealthAccessoryContextualCard in slot 2', (tester) async {
      final fakeProfile = ProfileModel(
        id: 1,
        firstName: 'Rahim',
        lastName: 'Ahmed',
        totalBagsDonated: 0,
        lastDonationDate: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _FakeProfileNotifier(fakeProfile)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HealthHubDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Status card must render
      expect(find.byType(HealthHubStatusCard), findsOneWidget);

      // Status card should display Eligible Now, never hardcoded 42 days
      expect(find.textContaining('Eligible Now'), findsOneWidget);
      expect(find.textContaining('42 days'), findsNothing);

      // In Dashboard, exactly one HealthAccessoryContextualCard in slot 2
      expect(find.byType(HealthAccessoryContextualCard), findsOneWidget);
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

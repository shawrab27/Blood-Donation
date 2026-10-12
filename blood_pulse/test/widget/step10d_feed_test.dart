// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/feed_view.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';
import 'package:blood_pulse/features/feed/presentation/providers/user_location_provider.dart';

void main() {
  group('Step 10D: Feed Widgets & Responsiveness', () {
    testWidgets('Renders feed with scope filter chips (Near me, My division, National)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FeedView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify scope filter chips
      expect(find.textContaining('Near me'), findsOneWidget);
      expect(find.text('My division'), findsOneWidget);
      expect(find.text('National'), findsOneWidget);

      // Verify type filters
      expect(find.text('All Updates'), findsOneWidget);
      expect(find.text('Campaign'), findsOneWidget);
      expect(find.text('Emergency'), findsOneWidget);
    });

    testWidgets('District change banner renders and interacts cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          userLocationProvider.overrideWith((ref) {
            final notifier = UserLocationNotifier();
            notifier.state = const UserLocationState(
              currentDistrictId: 2,
              districtName: 'Rangpur',
              divisionId: 2,
              divisionName: 'Rangpur',
              source: 'gps',
              changed: true,
            );
            return notifier;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: FeedView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify prompt banner appears
      expect(find.textContaining('You are in Rangpur now. Show Rangpur updates?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);

      // Tap Yes
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      // Banner dismissed
      expect(container.read(userLocationProvider).changed, isFalse);
    });

    testWidgets('RenderFlex safety across 4 viewport sizes with textScale 1.3', (tester) async {
      const viewports = [
        Size(320, 640),
        Size(360, 800),
        Size(412, 915),
        Size(600, 960),
      ];

      for (final vp in viewports) {
        await tester.binding.setSurfaceSize(vp);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: vp,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: const Scaffold(
                  body: FeedView(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow occurred at $vp with textScale 1.3');
      }

      await tester.binding.setSurfaceSize(null);
    });
  });
}

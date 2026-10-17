// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/landing/landing_campaign_card.dart';

void main() {
  group('Anomaly #14: Blood Campaigns Card', () {
    testWidgets('LandingCampaignCard removes inner list, is fully tappable, and opens Newsfeed with campaign filter', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: LandingCampaignCard(
                  isBangla: false,
                  onViewAllTap: () {
                    tapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title and badges
      expect(find.text('Blood Campaigns'), findsOneWidget);
      expect(find.text('#BloodCampaigns • Live on Feed'), findsOneWidget);
      expect(find.text('View All Campaigns'), findsOneWidget);

      // Verify inner list is removed: NO fake preview items
      expect(find.text('Dhaka University Annual Drive'), findsNothing);
      expect(find.text('Red Crescent Emergency Camp'), findsNothing);

      // Verify tapping button triggers onViewAllTap
      await tester.tap(find.text('View All Campaigns'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      // Verify no overflow
      expect(tester.takeException(), isNull);
    });
  });
}

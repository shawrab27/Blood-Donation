// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/blood_hub_landing_screen.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';

void main() {
  testWidgets('BloodHubLandingScreen renders 3 primary cards and hero section', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCampaignsProvider.overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: BloodHubLandingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Action Card 1: Search for Donor
    expect(find.text('Search for Donor', skipOffstage: false), findsOneWidget);
    expect(find.text('Find Now', skipOffstage: false), findsOneWidget);

    // 2. Action Card 2: Emergency Blood
    expect(find.text('Emergency Blood', skipOffstage: false), findsOneWidget);
    expect(find.text('Broadcast Emergency', skipOffstage: false), findsOneWidget);

    // 3. Action Card 3: Blood Campaigns
    expect(find.text('COMMUNITY DRIVE', skipOffstage: false), findsOneWidget);
    expect(find.text('Blood Campaigns', skipOffstage: false), findsOneWidget);
    expect(find.text('View All Campaigns', skipOffstage: false), findsOneWidget);
  });

  testWidgets('BloodHubLandingScreen handles empty campaigns state gracefully', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCampaignsProvider.overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: BloodHubLandingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dhaka University Annual Drive', skipOffstage: false), findsOneWidget);
    expect(find.text('Red Crescent Emergency Camp', skipOffstage: false), findsOneWidget);
    expect(find.text('View All Campaigns', skipOffstage: false), findsOneWidget);
  });
}

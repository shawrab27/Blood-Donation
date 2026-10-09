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

    // 1. Hero Section
    expect(find.text('Vital Community', skipOffstage: false), findsOneWidget);
    expect(find.text('The Heart of Giving', skipOffstage: false), findsOneWidget);

    // 2. Action Card 1: Search for Donor
    expect(find.text('Search for Donor', skipOffstage: false), findsOneWidget);
    expect(find.text('Find Now', skipOffstage: false), findsOneWidget);

    // 3. Action Card 2: Emergency Blood
    expect(find.text('Emergency Blood', skipOffstage: false), findsOneWidget);
    expect(find.text('Get Help Now', skipOffstage: false), findsOneWidget);

    // 4. Action Card 3: Blood Campaigns
    expect(find.text('Blood Campaigns', skipOffstage: false), findsOneWidget);

    // 5. Features Grid
    expect(find.text('Verified Network', skipOffstage: false), findsOneWidget);
    expect(find.text('Smart Proximity', skipOffstage: false), findsOneWidget);
    expect(find.text('Request History', skipOffstage: false), findsOneWidget);
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

    expect(find.textContaining('0 Drives Ongoing', skipOffstage: false), findsOneWidget);
    expect(find.text('No active blood campaigns nearby at this moment.', skipOffstage: false), findsOneWidget);
  });
}

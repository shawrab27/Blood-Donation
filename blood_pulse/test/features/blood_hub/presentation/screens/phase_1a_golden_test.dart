// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/presentation/screens/blood_hub_landing_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/donor_search_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/priority_requisition_screen.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';

class _ScreenMockDonorSearchNotifier extends DonorSearchNotifier {
  _ScreenMockDonorSearchNotifier();

  @override
  Future<DonorSearchPage> build() async {
    return const DonorSearchPage(
      donors: [
        DonorSearchModel(
          id: 1,
          name: 'Anonymous Altruist',
          bloodGroup: 'O+',
          component: 'WHOLE',
          district: 'Dhaka',
          division: 'Dhaka',
          campus: 'Medical College',
          isVerified: true,
          isEligible: true,
          trustBand: 'HIGH',
          maskedPhone: '+88017****1234',
        ),
      ],
      totalCount: 1,
    );
  }

  @override
  Future<void> loadMore() async {}
}

void main() {
  testWidgets('Golden BloodHubLanding 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCampaignsProvider.overrideWithValue([]),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: BloodHubLandingScreen()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(BloodHubLandingScreen),
      matchesGoldenFile('goldens/blood_hub_landing_360dp.png'),
    );
  });

  testWidgets('Golden BloodHubLanding 412dp', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeCampaignsProvider.overrideWithValue([]),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: BloodHubLandingScreen()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(BloodHubLandingScreen),
      matchesGoldenFile('goldens/blood_hub_landing_412dp.png'),
    );
  });

  testWidgets('Golden DonorSearch 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          donorSearchNotifierProvider.overrideWith(
            () => _ScreenMockDonorSearchNotifier(),
          ),
          donorMapPinsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: DonorSearchScreen()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(DonorSearchScreen),
      matchesGoldenFile('goldens/donor_search_360dp.png'),
    );
  });

  testWidgets('Golden DonorSearch 412dp', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          donorSearchNotifierProvider.overrideWith(
            () => _ScreenMockDonorSearchNotifier(),
          ),
          donorMapPinsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: DonorSearchScreen()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(DonorSearchScreen),
      matchesGoldenFile('goldens/donor_search_412dp.png'),
    );
  });

  testWidgets('Golden PriorityRequisition 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: PriorityBloodRequisitionScreen()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(PriorityBloodRequisitionScreen),
      matchesGoldenFile('goldens/priority_requisition_360dp.png'),
    );
  });

  testWidgets('Golden PriorityRequisition 412dp', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: PriorityBloodRequisitionScreen()),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(PriorityBloodRequisitionScreen),
      matchesGoldenFile('goldens/priority_requisition_412dp.png'),
    );
  });
}

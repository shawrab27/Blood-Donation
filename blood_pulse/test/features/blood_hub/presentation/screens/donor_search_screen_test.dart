// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/donor_search_screen.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';

void main() {
  testWidgets('DonorSearchScreen renders search bar, chips, and available donors', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockDonor = DonorSearchModel(
      id: 1,
      name: 'Test Altruist',
      bloodGroup: 'O+',
      component: 'WHOLE',
      district: 'Dhaka',
      division: 'Dhaka',
      campus: 'Medical College',
      isVerified: true,
      isEligible: true,
      trustBand: 'HIGH',
      maskedPhone: '+88017****1234',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          donorSearchNotifierProvider.overrideWith(() => _MockDonorSearchNotifier(
                DonorSearchPage(donors: [mockDonor], totalCount: 1),
              )),
          donorMapPinsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: DonorSearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search Donors'), findsOneWidget);
    expect(find.text('Request to All'), findsOneWidget);
    expect(find.text('Search as Donor'), findsOneWidget);
    expect(find.text('Request for Blood'), findsOneWidget);
    expect(find.text('Available Donors'), findsOneWidget);
    expect(find.text('1 found near you'), findsOneWidget);
    expect(find.text('Test Altruist'), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);
  });

  testWidgets('DonorSearchScreen renders empty state when no donors match', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          donorSearchNotifierProvider.overrideWith(() => _MockDonorSearchNotifier(
                const DonorSearchPage(donors: [], totalCount: 0),
              )),
          donorMapPinsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: DonorSearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No donors found matching criteria'), findsOneWidget);
    expect(find.text('Clear Filters'), findsOneWidget);
  });

  testWidgets('DonorSearchScreen renders error state on failure', (tester) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          donorSearchNotifierProvider.overrideWith(() => _ErrorDonorSearchNotifier()),
          donorMapPinsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: DonorSearchScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to load donors'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _MockDonorSearchNotifier extends DonorSearchNotifier {
  _MockDonorSearchNotifier(this._page);
  final DonorSearchPage _page;

  @override
  Future<DonorSearchPage> build() async => _page;

  @override
  Future<void> loadMore() async {}
}

class _ErrorDonorSearchNotifier extends DonorSearchNotifier {
  @override
  Future<DonorSearchPage> build() async {
    throw Exception('Network connection timed out');
  }

  @override
  Future<void> loadMore() async {}
}

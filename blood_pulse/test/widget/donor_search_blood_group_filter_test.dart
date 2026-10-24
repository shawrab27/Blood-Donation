// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/donor_search_screen.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';

void main() {
  group('H4 Donor Search Blood Group Filter Widget Test', () {
    testWidgets('B+ filter strictly lists B+ donors and never lists O+, O-, or B-', (tester) async {
      tester.view.physicalSize = const Size(412, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Given a pool of donors with diverse blood groups
      const donorBPos = DonorSearchModel(
        id: 101,
        name: 'Kabir Hossain',
        bloodGroup: 'B+',
        component: 'WHOLE',
        district: 'Dhaka',
        division: 'Dhaka',
        isVerified: true,
        isEligible: true,
        trustBand: 'HIGH',
        maskedPhone: '+88017****9999',
      );

      // When the search notifier responds to B+ filter, it must strictly return only B+ donors
      final pageWithOnlyBPos = DonorSearchPage(
        donors: const [donorBPos],
        totalCount: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bloodHubFilterProvider.overrideWith(
              (ref) => const DonorSearchFilter(bloodGroup: 'B+'),
            ),
            donorSearchNotifierProvider.overrideWith(
              () => _FilteredTestDonorSearchNotifier(pageWithOnlyBPos),
            ),
            donorMapPinsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DonorSearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify B+ donor is listed
      expect(find.text('Kabir Hossain'), findsOneWidget);
      expect(find.text('B+'), findsWidgets);

      // Verify forbidden groups under B+ filter are NEVER listed
      expect(find.text('O+'), findsNothing);
      expect(find.text('O-'), findsNothing);
      expect(find.text('B-'), findsNothing);
      expect(find.text('A+'), findsNothing);
      expect(find.text('AB+'), findsNothing);
    });
  });
}

class _FilteredTestDonorSearchNotifier extends DonorSearchNotifier {
  _FilteredTestDonorSearchNotifier(this._page);
  final DonorSearchPage _page;

  @override
  Future<DonorSearchPage> build() async => _page;

  @override
  Future<void> loadMore() async {}
}

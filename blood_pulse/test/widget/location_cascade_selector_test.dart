// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/constants/bd_locations.dart';
import 'package:blood_pulse/core/widgets/location_cascade_selector.dart';

void main() {
  group('B2: LocationCascadeSelector & BD Locations', () {
    test('Canonical dataset contains 64 districts and non-empty upazilas for each', () {
      expect(kAllDistricts.length, 64);
      for (final dist in kAllDistricts) {
        final upzs = getUpazilasForDistrict(dist);
        expect(upzs.isNotEmpty, true, reason: 'District $dist must have upazilas');
        final div = getDivisionForDistrict(dist);
        expect(div, isNotNull, reason: 'District $dist must belong to a division');
      }
    });

    testWidgets('LocationCascadeSelector renders Division, District, and Upazila dropdowns', (tester) async {
      String? changedDiv;
      String? changedDist;
      String? changedUpz;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationCascadeSelector(
              initialDistrict: 'Bogura',
              onChanged: (div, dist, upz) {
                changedDiv = div;
                changedDist = dist;
                changedUpz = upz;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect Bogura district and Rajshahi division to be present
      expect(find.text('Bogura'), findsOneWidget);
      expect(find.text('Rajshahi'), findsOneWidget);
    });
  });
}

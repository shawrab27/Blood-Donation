// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/constants/bd_locations.dart';

void main() {
  group('Bangladesh Locations Bundled Map Unit Tests (Step 7b)', () {
    const expectedDivisionCounts = {
      'Dhaka': 13,
      'Chattogram': 11,
      'Rajshahi': 8,
      'Khulna': 10,
      'Barishal': 6,
      'Sylhet': 4,
      'Rangpur': 8,
      'Mymensingh': 4,
    };

    test('kBangladeshDivisionsAndDistricts has 8 divisions and 64 total districts', () {
      expect(kBangladeshDivisionsAndDistricts.keys.length, equals(8));
      expect(kBangladeshDivisionsAndDistricts.keys.toSet(), equals(expectedDivisionCounts.keys.toSet()));

      int totalDistricts = 0;
      for (final entry in expectedDivisionCounts.entries) {
        final districts = kBangladeshDivisionsAndDistricts[entry.key];
        expect(districts, isNotNull, reason: 'Division ${entry.key} must exist');
        expect(districts!.length, equals(entry.value),
            reason: 'Division ${entry.key} must have exactly ${entry.value} districts');
        totalDistricts += districts.length;
      }
      expect(totalDistricts, equals(64));
    });

    test('All district names are canonical non-empty strings with no tree artifacts', () {
      for (final division in kBangladeshDivisionsAndDistricts.keys) {
        final districts = kBangladeshDivisionsAndDistricts[division]!;
        for (final district in districts) {
          expect(district.trim(), equals(district), reason: 'District $district should have no leading/trailing whitespace');
          expect(district.contains('├'), isFalse, reason: 'District $district must not contain tree characters');
          expect(district.contains('└'), isFalse, reason: 'District $district must not contain tree characters');
          expect(district.contains('─'), isFalse, reason: 'District $district must not contain tree characters');
        }
      }
    });

    test('Specific districts match canonical app spelling', () {
      expect(kBangladeshDivisionsAndDistricts['Rajshahi']!.contains('Chapai Nawabganj'), isTrue);
      expect(kBangladeshDivisionsAndDistricts['Barishal']!.contains('Jhalokati'), isTrue);
      expect(kBangladeshDivisionsAndDistricts['Chattogram']!.contains('Cumilla'), isTrue);
      expect(kBangladeshDivisionsAndDistricts['Khulna']!.contains('Jashore'), isTrue);
      expect(kBangladeshDivisionsAndDistricts['Rajshahi']!.contains('Bogura'), isTrue);
    });
  });
}

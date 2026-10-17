// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/donor_search/donor_card.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';

void main() {
  group('Step 4 Privacy: DonorCard 4 Display Fields', () {
    testWidgets('DonorCard renders ONLY the 4 fields: District, Donor Name, Blood Group, and Tier Badge', (tester) async {
      const donor = DonorSearchModel(
        id: 42,
        name: 'Kabir Hossain',
        bloodGroup: 'B+',
        component: 'WHOLE',
        district: 'Sylhet',
        division: 'Sylhet',
        isVerified: true,
        isEligible: true,
        trustBand: 'HIGH',
        badge: 'Gold Donor',
        campus: 'SUST Medical Unit', // Must NOT be rendered per privacy rules
        maskedPhone: '+88017****9999', // Must NOT be rendered per privacy rules
      );

      bool requested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonorCard(
              donor: donor,
              onRequestTap: () {
                requested = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Donor's Name
      expect(find.text('Kabir Hossain'), findsOneWidget);

      // 2. District Name
      expect(find.text('Sylhet'), findsOneWidget);

      // 3. Blood Group
      expect(find.text('B+'), findsOneWidget);

      // 4. Platform Tier Badge
      expect(find.text('Gold Donor'), findsOneWidget);

      // Verify privacy enforcement: NO phone, NO exact campus, NO distance rendered
      expect(find.text('+88017****9999'), findsNothing);
      expect(find.text('SUST Medical Unit'), findsNothing);
      expect(find.textContaining('km away'), findsNothing);

      // Verify Request button is present and clickable
      final requestBtn = find.text('Request');
      expect(requestBtn, findsOneWidget);
      await tester.tap(requestBtn);
      await tester.pumpAndSettle();

      // Check popup card shows district and badge, and Send Request triggers callback
      expect(find.textContaining('Sylhet • Gold Donor'), findsOneWidget);
      final sendRequestBtn = find.text('Send Request');
      expect(sendRequestBtn, findsOneWidget);
      await tester.tap(sendRequestBtn);
      await tester.pumpAndSettle();

      expect(requested, isTrue);
    });

    testWidgets('CompactDonorCard renders 2-per-row compact view and tap opens detail popup with zero PII', (tester) async {
      const donor = DonorSearchModel(
        id: 42,
        name: 'Kabir Hossain',
        bloodGroup: 'B+',
        component: 'WHOLE',
        district: 'Sylhet',
        division: 'Sylhet',
        isVerified: true,
        isEligible: true,
        trustBand: 'HIGH',
        badge: 'Lifesaver Donor',
        campus: 'SUST Medical Unit',
        maskedPhone: '+88017****9999',
      );

      bool requested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactDonorCard(
              donor: donor,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card displays: Blood group, Name, Badge/Title, District
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Kabir Hossain'), findsOneWidget);
      expect(find.text('Lifesaver Donor'), findsOneWidget);
      expect(find.text('Sylhet'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);

      // Strictly zero PII on card
      expect(find.text('+88017****9999'), findsNothing);
      expect(find.text('SUST Medical Unit'), findsNothing);

      // Now test showDonorDetailPopup
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDonorDetailPopup(
                    context,
                    donor,
                    onRequestTap: () {
                      requested = true;
                    },
                  );
                },
                child: const Text('Open Detail'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      // Popup displays title, blood group, general location
      expect(find.text('Lifesaver Donor'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Sylhet, Sylhet'), findsOneWidget);
      expect(find.textContaining('Privacy locked'), findsOneWidget);

      // Strictly zero PII in popup
      expect(find.text('+88017****9999'), findsNothing);
      expect(find.text('SUST Medical Unit'), findsNothing);

      // Action button
      final reqBtn = find.text('Request Blood');
      expect(reqBtn, findsOneWidget);
      await tester.tap(reqBtn);
      await tester.pumpAndSettle();

      expect(requested, isTrue);
    });
  });
}

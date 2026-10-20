// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/donor_search/donor_card.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('TASK P-04 (Anomaly N4): DonorCard Redesign & Privacy Tests', () {
    const testDonor = DonorSearchModel(
      id: 99,
      name: 'Tanvir Ahmed',
      bloodGroup: 'AB+',
      component: 'WHOLE',
      district: 'Rajshahi',
      division: 'Rajshahi',
      isVerified: true,
      isEligible: true,
      trustBand: 'HIGH',
      badge: 'Platinum Donor',
      campus: 'RUET Campus Medical', // Strictly private
      maskedPhone: '+88017****5555', // Strictly private
    );

    testWidgets('A1: Card uses dark red background with white text and contrast >= 4.5:1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFFFDF3F3),
            body: Center(
              child: SizedBox(
                width: 170,
                height: 180,
                child: DonorCard(
                  donor: testDonor,
                  onRequestTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check card background color
      final inkFinder = find.byType(Ink);
      expect(inkFinder, findsOneWidget);
      final ink = tester.widget<Ink>(inkFinder);
      final dec = ink.decoration as BoxDecoration;
      expect(dec.color, equals(kDonorCardDarkRed));

      // Calculate contrast ratio against white text (WCAG requirement >= 4.5:1)
      final contrast = _contrastRatio(kDonorCardDarkRed, Colors.white);
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(contrast, greaterThanOrEqualTo(7.0)); // Meets AAA

      // Check that white text is rendered
      final nameFinder = find.text('Tanvir Ahmed');
      expect(nameFinder, findsOneWidget);
      final nameText = tester.widget<Text>(nameFinder);
      expect(nameText.style?.color, equals(Colors.white));
    });

    testWidgets('A3: Card displays ONLY the 4 privacy fields (no phone, no campus, no GPS)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFFFDF3F3),
            body: Center(
              child: SizedBox(
                width: 170,
                height: 180,
                child: DonorCard(
                  donor: testDonor,
                  onRequestTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Name
      expect(find.text('Tanvir Ahmed'), findsOneWidget);
      // 2. Blood Group
      expect(find.text('AB+'), findsOneWidget);
      // 3. District
      expect(find.text('Rajshahi'), findsOneWidget);
      // 4. Platform Tier
      expect(find.text('Platinum Donor'), findsOneWidget);

      // Verify privacy exclusions
      expect(find.text('+88017****5555'), findsNothing);
      expect(find.text('RUET Campus Medical'), findsNothing);
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.textContaining('km away'), findsNothing);
    });

    testWidgets('A2: Tapping card opens detail popup showing only 4 allowed fields + Request button', (tester) async {
      bool requestCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 180,
                child: DonorCard(
                  donor: testDonor,
                  onRequestTap: () {
                    requestCalled = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap card to open popup
      await tester.tap(find.byType(DonorCard));
      await tester.pumpAndSettle();

      // Popup header shows Donor Name and Blood Group
      expect(find.text('Tanvir Ahmed'), findsNWidgets(2)); // Card + Popup
      expect(find.text('AB+'), findsNWidgets(2)); // Card + Popup
      expect(find.textContaining('Platinum Donor'), findsNWidgets(2)); // Card + Popup
      expect(find.textContaining('Rajshahi'), findsNWidgets(2)); // Card + Popup

      // Popup displays privacy reassurance notice
      expect(find.textContaining('Direct requisition will send priority push notification'), findsOneWidget);

      // Verify strictly NO phone or campus in popup
      expect(find.text('+88017****5555'), findsNothing);
      expect(find.text('RUET Campus Medical'), findsNothing);

      // Verify Close button dismisses popup
      final closeBtn = find.text('Close');
      expect(closeBtn, findsOneWidget);

      // Verify Send Request button triggers callback
      final requestActionBtn = find.text('Send Request');
      expect(requestActionBtn, findsOneWidget);
      await tester.tap(requestActionBtn);
      await tester.pumpAndSettle();

      expect(requestCalled, isTrue);
    });

    testWidgets('Popup Close button dismisses the popup sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 180,
                child: DonorCard(
                  donor: testDonor,
                  onRequestTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup
      await tester.tap(find.byType(DonorCard));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);

      // Tap Close
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('A4: Responsive 2-per-row grid overflow sweep at 4 screen sizes and text scale 1.3', (tester) async {
      final viewports = [
        const Size(320, 568), // Compact phone
        const Size(360, 800), // Mid-range phone
        const Size(390, 844), // Modern iPhone
        const Size(412, 915), // Large Android
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: Scaffold(
                backgroundColor: const Color(0xFFFDF3F3),
                body: SafeArea(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, i) => DonorCard(
                      donor: testDonor,
                      onRequestTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify zero RenderFlex overflows
        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected at size $size with textScale 1.3');
        expect(find.byType(DonorCard), findsNWidgets(4));
      }
    });
  });
}

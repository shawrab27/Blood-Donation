// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/dialogs/private_donor_feedback_dialog.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/modals/digital_certificate_sheet.dart';

void main() {
  group('PrivateDonorFeedbackDialog Widget Tests', () {
    testWidgets('renders 5 stars, tags, submit and later buttons without overflow at 320x568 and textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PrivateDonorFeedbackDialog.show(
                    context: context,
                    requestId: 123,
                    hospitalName: 'Dhaka Medical',
                    onDismiss: () => dismissed = true,
                  ),
                  child: const Text('Open Feedback'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Feedback'));
      await tester.pumpAndSettle();

      // Check dialog elements
      expect(find.text('How was your donation experience?'), findsOneWidget);
      expect(find.text('Your feedback helps maintain community safety and is never shown to the requester.'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
      expect(find.text('Polite & Respectful'), findsOneWidget);
      expect(find.text('Offered Travel Support'), findsOneWidget);
      expect(find.text('Submit Private Feedback'), findsOneWidget);
      expect(find.text('Skip / Later'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Scroll to ensure button is visible in SingleChildScrollView and tap
      await tester.scrollUntilVisible(find.text('Skip / Later'), 50.0);
      await tester.pumpAndSettle();

      // Tap Skip / Later
      await tester.tap(find.text('Skip / Later'));
      await tester.pumpAndSettle();

      // Dialog is popped and onDismiss called
      expect(find.byType(PrivateDonorFeedbackDialog), findsNothing);
      expect(dismissed, isTrue);
    });
  });

  group('DigitalCertificateSheet Widget Tests', () {
    testWidgets('renders verified donor wording, donations completed, tier badge, no phone/email/location', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DigitalCertificateSheet.show(
                  context: context,
                  donorName: 'Tanvir Ahmed',
                  bloodGroup: 'B+',
                  totalDonations: 7,
                ),
                child: const Text('View Certificate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('View Certificate'));
      await tester.pumpAndSettle();

      // Verify certificate text and strict wording "Donations completed"
      expect(find.text('Digital Donor Certificate'), findsOneWidget);
      expect(find.text('CERTIFICATE OF RECOGNITION'), findsOneWidget);
      expect(find.text('Tanvir Ahmed'), findsOneWidget);
      expect(find.text('Donations completed: 7 (Blood Group: B+).'), findsOneWidget);
      expect(find.text('BloodPulse Verified Donor • Tier Gold'), findsOneWidget);
      expect(find.text('Share Certificate'), findsOneWidget);

      // Ensure no raw phone, email, or exact location is present
      expect(find.textContaining('017'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('Latitude'), findsNothing);
      expect(find.textContaining('Longitude'), findsNothing);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}

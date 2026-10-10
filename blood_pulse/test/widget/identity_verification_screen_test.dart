// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_request/presentation/screens/identity_verification_screen.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';

void main() {
  Widget buildScreen({String email = 'requester@example.com', bool autoSend = false}) {
    return ProviderScope(
      child: MaterialApp(
        home: IdentityVerificationScreen(
          patientName: 'Test Patient',
          bloodGroup: 'B+',
          urgencyLevel: 'Critical',
          hospitalLocation: 'Dhaka Medical',
          contactNumber: '01711111111',
          email: email,
          autoSend: autoSend,
        ),
      ),
    );
  }

  testWidgets('Renders 3 method tabs: Email, WhatsApp, and Phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Enter 6-Digit OTP'), findsOneWidget);
    expect(find.byType(CapsuleButton), findsOneWidget);
  });

  testWidgets('Tapping WhatsApp tab shows Coming Soon dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.text('WhatsApp'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('WhatsApp Verification'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('WhatsApp Verification'), findsNothing);
  });

  testWidgets('Tapping Phone tab shows Coming Soon dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.text('Phone'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Phone Number Verification'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Phone Number Verification'), findsNothing);
  });

  testWidgets('6-digit paste populates pin boxes and triggers auto-submit check', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // 6 pin text fields + 1 email text field
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(7));

    // The first TextField is the email input; fields 1..6 are the 6 PIN boxes
    await tester.enterText(textFields.at(1), '654321');
    await tester.pump();

    expect(tester.widget<TextField>(textFields.at(1)).controller?.text, '6');
    expect(tester.widget<TextField>(textFields.at(6)).controller?.text, '1');
  });

  testWidgets('Resend timer starts at 60s and counts down', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.textContaining('Resend code in 00:'), findsOneWidget);

    // Advance 61 seconds
    await tester.pump(const Duration(seconds: 61));

    expect(find.text('Didn’t receive code? Resend Code'), findsOneWidget);
  });

  testWidgets('Keypad buttons append digits to pin fields', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // Ensure keypad button '5' is visible
    final btnFinder = find.widgetWithText(InkWell, '5');
    await tester.ensureVisible(btnFinder);
    await tester.pump();

    await tester.tap(btnFinder);
    await tester.pump();

    final textFields = find.byType(TextField);
    expect(tester.widget<TextField>(textFields.at(1)).controller?.text, '5');
  });
}

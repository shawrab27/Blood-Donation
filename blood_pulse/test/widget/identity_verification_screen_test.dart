import 'package:http/http.dart' as http;
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_request/presentation/screens/identity_verification_screen.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';
import 'package:blood_pulse/services/api_client.dart';

class FakeOtpApiClient extends ApiClient {
  int sendOtpCalls = 0;
  String? sentEmail;

  @override
  Future<Map<String, dynamic>> sendRequestOtp({String? email}) async {
    sendOtpCalls++;
    sentEmail = email;
    return {'cooldown_seconds': 60};
  }

  @override
  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) async {
    return http.Response('{"status": "ok"}', 200);
  }
}

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


  testWidgets('Emergency request without Ward/Bed stops OTP dispatch with clear inline error', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeClient = FakeOtpApiClient();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: IdentityVerificationScreen(
            email: 'guest@example.com',
            emergencyPayload: const {
              'patient_name': 'Emergency Patient',
              'blood_group': 'O+',
              'hospital_name_other': 'Dhaka Medical',
              // 'ward_bed' is intentionally omitted/missing
            },
            apiClient: fakeClient,
            autoSend: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify OTP was NOT dispatched
    expect(fakeClient.sendOtpCalls, 0);

    // Verify clear inline error message is shown
    expect(find.text('Ward/Bed information is required.'), findsAtLeastNWidgets(1));

    // Verify Ward / Bed input field is rendered
    expect(find.byKey(const Key('ward_bed_field')), findsOneWidget);

    // Now enter Ward/Bed and tap retry button
    await tester.enterText(find.byKey(const Key('ward_bed_field')), 'Ward 3, Bed 12');
    await tester.pump();

    final retryBtn = find.byKey(const Key('otp_retry_button'));
    expect(retryBtn, findsOneWidget);
    await tester.tap(retryBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Now OTP should be dispatched!
    expect(fakeClient.sendOtpCalls, 1);
    expect(fakeClient.sentEmail, 'guest@example.com');
  });

  testWidgets('Standard non-emergency request does not require Ward/Bed to dispatch OTP', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeClient = FakeOtpApiClient();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: IdentityVerificationScreen(
            email: 'regular@example.com',
            emergencyPayload: null, // standard request
            apiClient: fakeClient,
            autoSend: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Ward/Bed field is NOT rendered for standard requests
    expect(find.byKey(const Key('ward_bed_field')), findsNothing);

    // OTP was dispatched normally
    expect(fakeClient.sendOtpCalls, 1);
    expect(fakeClient.sentEmail, 'regular@example.com');
  });
}

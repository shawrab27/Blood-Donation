// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/enums/otp_delivery_state.dart';
import 'package:blood_pulse/features/auth/presentation/screens/verify_otp_reset_screen.dart';
import 'package:blood_pulse/features/blood_request/presentation/screens/identity_verification_screen.dart';

void main() {
  group('OTP 3-State Widget Tests (G3)', () {
    testWidgets('VerifyOtpResetScreen renders Sending state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VerifyOtpResetScreen(
              email: 'applicant@gmail.com',
              initialDeliveryState: OtpDeliveryState.sending,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('otp_state_sending')), findsOneWidget);
      expect(find.text('Sending verification code...'), findsOneWidget);
      // Bell and profile icons must NOT be present
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('VerifyOtpResetScreen renders Sent state with masked email & countdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VerifyOtpResetScreen(
              email: 'applicant@gmail.com',
              initialDeliveryState: OtpDeliveryState.sent,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('otp_state_sent')), findsOneWidget);
      expect(find.text('Code sent to a***@gmail.com'), findsOneWidget);
      expect(find.textContaining('Resend OTP in 00:'), findsOneWidget);
    });

    testWidgets('VerifyOtpResetScreen renders Failure state with Retry button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VerifyOtpResetScreen(
              email: 'applicant@gmail.com',
              initialDeliveryState: OtpDeliveryState.failure,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('otp_state_failure')), findsOneWidget);
      expect(find.byKey(const Key('otp_retry_button')), findsOneWidget);
    });

    testWidgets('IdentityVerificationScreen renders Sending state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: IdentityVerificationScreen(
              email: 'applicant@gmail.com',
              autoSend: false,
              initialDeliveryState: OtpDeliveryState.sending,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('otp_state_sending')), findsOneWidget);
      expect(find.text('Sending verification code...'), findsOneWidget);
      // Bell and profile icons must NOT be present
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('IdentityVerificationScreen renders Sent state with masked email', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: IdentityVerificationScreen(
              email: 'applicant@gmail.com',
              autoSend: false,
              initialDeliveryState: OtpDeliveryState.sent,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('otp_state_sent')), findsOneWidget);
      expect(find.text('Code sent to a***@gmail.com'), findsOneWidget);
      expect(find.textContaining('Resend code in 00:'), findsOneWidget);
    });

    testWidgets('IdentityVerificationScreen renders Failure state with Retry button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: IdentityVerificationScreen(
              email: 'applicant@gmail.com',
              autoSend: false,
              initialDeliveryState: OtpDeliveryState.failure,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('otp_state_failure')), findsOneWidget);
      expect(find.byKey(const Key('otp_retry_button')), findsOneWidget);
    });
  });
}

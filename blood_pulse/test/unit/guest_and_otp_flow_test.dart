// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/core/access/access_guard.dart';
import 'package:blood_pulse/features/auth/presentation/widgets/otp_input_row.dart';

void main() {
  group('Guest Session & Auth State Tests', () {
    test('continueAsGuest() sets isGuest to true and status to unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial state
      expect(container.read(isGuestProvider), isFalse);
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);

      // Call continueAsGuest()
      container.read(authProvider.notifier).continueAsGuest();

      // Assert guest flag is true and status is unauthenticated
      expect(container.read(isGuestProvider), isTrue);
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authProvider).isAuthenticated, isFalse);
    });

    test('logout() clears tokens, resets isGuest to false, and clears pending redirect', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set guest state and pending redirect
      container.read(isGuestProvider.notifier).state = true;
      container.read(pendingRedirectRouteProvider.notifier).state = '/emergency/requests';

      expect(container.read(isGuestProvider), isTrue);
      expect(container.read(pendingRedirectRouteProvider), equals('/emergency/requests'));

      // Perform logout
      await container.read(authProvider.notifier).logout();

      // Assert everything is reset
      expect(container.read(isGuestProvider), isFalse);
      expect(container.read(pendingRedirectRouteProvider), isNull);
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authProvider).user, isNull);
    });
  });

  group('OTP Input Row Auto-Advance & Paste Behavior', () {
    testWidgets('Typing a digit into OTP box auto-advances focus to next box', (tester) async {
      final controllers = List.generate(6, (_) => TextEditingController());
      final nodes = List.generate(6, (_) => FocusNode());

      void handleOtpInput(String value, int index) {
        if (value.isNotEmpty && index < 5) {
          nodes[index + 1].requestFocus();
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputRow(
              controllers: controllers,
              nodes: nodes,
              onChanged: handleOtpInput,
            ),
          ),
        ),
      );

      final otpFields = find.byType(TextFormField);
      expect(otpFields, findsNWidgets(6));

      // Enter '5' into the 1st box
      await tester.enterText(otpFields.at(0), '5');
      await tester.pumpAndSettle();

      expect(controllers[0].text, equals('5'));
      expect(nodes[1].hasFocus, isTrue, reason: 'Focus should have auto-advanced to 2nd box');

      // Enter '8' into the 2nd box
      await tester.enterText(otpFields.at(1), '8');
      await tester.pumpAndSettle();

      expect(controllers[1].text, equals('8'));
      expect(nodes[2].hasFocus, isTrue, reason: 'Focus should have auto-advanced to 3rd box');
    });

    testWidgets('Pasting 6 digits into 1st OTP box fills all 6 boxes', (tester) async {
      final controllers = List.generate(6, (_) => TextEditingController());
      final nodes = List.generate(6, (_) => FocusNode());

      void handleOtpInput(String value, int index) {
        if (value.length > 1) {
          final paste = value.replaceAll(RegExp(r'[^0-9]'), '');
          for (int i = 0; i < paste.length && i < 6; i++) {
            controllers[i].text = paste[i];
          }
          if (paste.length < 6) {
            nodes[paste.length].requestFocus();
          } else {
            nodes[5].unfocus();
          }
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInputRow(
              controllers: controllers,
              nodes: nodes,
              onChanged: handleOtpInput,
            ),
          ),
        ),
      );

      final otpFields = find.byType(TextFormField);
      expect(otpFields, findsNWidgets(6));

      // Paste '987654' into the first box
      await tester.enterText(otpFields.at(0), '987654');
      await tester.pumpAndSettle();

      // Each of the 6 boxes must hold the respective character
      expect(controllers[0].text, equals('9'));
      expect(controllers[1].text, equals('8'));
      expect(controllers[2].text, equals('7'));
      expect(controllers[3].text, equals('6'));
      expect(controllers[4].text, equals('5'));
      expect(controllers[5].text, equals('4'));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/auth/presentation/screens/verify_otp_reset_screen.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: VerifyOtpResetScreen(email: 'test@example.com'),
      ),
    );
  }

  testWidgets('6-digit paste fills all fields', (tester) async {
    await tester.pumpWidget(buildScreen());
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(8)); // 6 OTP + 1 Password + 1 Confirm

    // Paste into first field
    await tester.enterText(textFields.at(0), '123456');
    await tester.pumpAndSettle();

    expect((tester.widget<TextFormField>(textFields.at(0)).controller?.text), '1');
    expect((tester.widget<TextFormField>(textFields.at(5)).controller?.text), '6');
  });

  testWidgets('Resend button disabled during countdown and enabled at 0', (tester) async {
    await tester.pumpWidget(buildScreen());
    
    // Initially disabled
    expect(find.textContaining('Resend OTP in'), findsOneWidget);
    
    // Advance time by 46 seconds
    await tester.pump(const Duration(seconds: 46));
    
    // Now enabled
    expect(find.text('Resend OTP'), findsOneWidget);
  });

  testWidgets('Confirm mismatch disables submit button', (tester) async {
    await tester.pumpWidget(buildScreen());
    final textFields = find.byType(TextFormField);
    
    // Fill OTP
    await tester.enterText(textFields.at(0), '123456');
    
    // Enter mismatched passwords
    await tester.enterText(textFields.at(6), 'Password123');
    await tester.enterText(textFields.at(7), 'Different123');
    await tester.pumpAndSettle();
    
    final submitBtn = tester.widget<CapsuleButton>(find.byType(CapsuleButton));
    expect(submitBtn.onPressed, isNull);
  });
}

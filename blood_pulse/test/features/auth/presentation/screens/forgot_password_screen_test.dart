import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';

void main() {
  testWidgets('ForgotPasswordScreen shows UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      ),
    );
    
    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(CapsuleButton), findsOneWidget);
  });
}

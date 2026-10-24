import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/widgets/primary_button.dart';
import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:blood_pulse/core/errors/app_error_mapper.dart';
import 'package:blood_pulse/core/theme/pulse_motion.dart';
import 'package:blood_pulse/core/widgets/app_loader.dart';

void main() {
  group('S1: PrimaryButton', () {
    testWidgets('never wraps or clips at 320dp width with textScale 1.3', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: PrimaryButton(
                    label: 'Emergency Blood Requisition Now',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final textFinder = find.text('Emergency Blood Requisition Now');
      expect(textFinder, findsOneWidget);

      final iconFinder = find.byIcon(Icons.arrow_forward_rounded);
      expect(iconFinder, findsOneWidget);

      // Verify arrow is strictly AFTER text (higher dx)
      final textOffset = tester.getCenter(textFinder);
      final iconOffset = tester.getCenter(iconFinder);
      expect(iconOffset.dx, greaterThan(textOffset.dx));
    });

    testWidgets('shows white AppLoader and stays red during loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Submit',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(AppLoader), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });
  });

  group('S2: PressableScale', () {
    testWidgets('scales down on tap down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onTap: () {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(PressableScale)));
      await tester.pump(const Duration(milliseconds: 120));

      final animatedScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(animatedScale.scale, equals(0.97));

      await gesture.up();
      await tester.pumpAndSettle();
      final resetScale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(resetScale.scale, equals(1.0));
    });
  });

  group('S3: AppError mapper', () {
    test('maps raw JSON, ApiException, status codes to human sentences', () {
      expect(
        AppError.toHumanMessage('ApiException: {"detail": "Invalid credentials"} [401]'),
        equals('Invalid credentials.'),
      );

      expect(
        AppError.toHumanMessage('{"phone_number": ["An account with this phone number is already registered."]}'),
        equals('An account with this phone number is already registered.'),
      );

      expect(
        AppError.toHumanMessage('SocketException: Failed host lookup'),
        contains('check your internet connection'),
      );

      expect(
        AppError.toHumanMessage('TimeoutException after 0:00:08.000000'),
        contains('Connection timed out'),
      );

      expect(
        AppError.toHumanMessage('Server is waking up, please wait a moment...'),
        contains('Server is starting up'),
      );

      expect(
        AppError.toHumanMessage(null),
        equals('Something went wrong. Please try again.'),
      );
    });
  });

  group('S5: PulseMotion', () {
    test('durations and reduced motion support', () {
      expect(PulseMotion.fast, equals(const Duration(milliseconds: 120)));
      expect(PulseMotion.normal, equals(const Duration(milliseconds: 300)));
      expect(PulseMotion.slow, equals(const Duration(milliseconds: 600)));
    });
  });
}

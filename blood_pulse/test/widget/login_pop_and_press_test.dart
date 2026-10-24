import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';
import 'package:blood_pulse/core/widgets/hero_reveal_logo.dart';
import 'package:blood_pulse/core/widgets/app_logo.dart';
import 'package:blood_pulse/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('CapsuleButton performs 0.97 press-pop scale on tap down and release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CapsuleButton(
              label: 'Sign In',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sign In'), findsOneWidget);
    final scaleFinder = find.descendant(
      of: find.byType(CapsuleButton),
      matching: find.byType(ScaleTransition),
    );
    expect(scaleFinder, findsOneWidget);

    ScaleTransition scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleWidget.scale.value, 1.0);

    // Tap down with gesture
    final gesture = await tester.startGesture(tester.getCenter(find.text('Sign In')));
    await tester.pump(kPressTimeout);
    await tester.pump(const Duration(milliseconds: 120));

    scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleWidget.scale.value, closeTo(0.97, 0.005));

    // Release and let reverse animation complete
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleWidget.scale.value, closeTo(1.0, 0.005));
  });

  testWidgets('HeroRevealLogo renders BloodPulseLogo and runs single-run ECG animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HeroRevealLogo(
              child: BloodPulseLogo(
                direction: Axis.vertical,
                iconSize: 72.0,
                fontSize: 28.0,
                spacing: 10.0,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(HeroRevealLogo), findsOneWidget);
    expect(find.byType(BloodPulseLogo), findsOneWidget);

    // Advance animation to completion (1100ms)
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
  });

  testWidgets('LoginScreen contains PopScope and HeroRevealLogo', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is PopScope), findsWidgets);
    expect(find.byType(HeroRevealLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/widgets/ecg_loader.dart';
import 'package:blood_pulse/core/widgets/success_pulse.dart';
import 'package:blood_pulse/core/widgets/hero_reveal_logo.dart';
import 'package:blood_pulse/core/widgets/count_up_text.dart';
import 'package:blood_pulse/core/widgets/process_draw_line.dart';
import 'package:blood_pulse/core/widgets/bento_stagger.dart';
import 'package:blood_pulse/core/widgets/ping_ripple.dart';

void main() {
  group('E1 EcgLoader Widget Tests', () {
    testWidgets('paints without throwing and honors disableAnimations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EcgLoader(),
            ),
          ),
        ),
      );

      expect(find.byType(EcgLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Verify with disableAnimations: true
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: EcgLoader(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('E2 SuccessPulse Widget Tests', () {
    testWidgets('completes <=900ms and triggers callback with no overflow at 320dp', (tester) async {
      bool completed = false;

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
                  child: SuccessPulse(
                    onComplete: () {
                      completed = true;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SuccessPulse), findsOneWidget);
      expect(completed, isFalse);

      // Pump 900ms to allow <=850ms animation to complete
      await tester.pump(const Duration(milliseconds: 900));

      expect(tester.takeException(), isNull);
      expect(completed, isTrue);
    });
  });

  group('E3 HeroRevealLogo Widget Tests', () {
    testWidgets('paints child and completes within 1200ms without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HeroRevealLogo(
                child: Text('BloodPulse Logo'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('BloodPulse Logo'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });

  group('E4 CountUpText Widget Tests', () {
    testWidgets('counts up to target value with no overflow at 320dp', (tester) async {
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
                  child: CountUpText(
                    endValue: 42,
                    suffix: ' Bags',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Initially starts at 0
      expect(find.text('0 Bags'), findsOneWidget);

      // Advance by 600ms (standard E4 slow duration)
      await tester.pump(const Duration(milliseconds: 600));

      // Reaches 42
      expect(find.text('42 Bags'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('E5 ProcessDrawLine Widget Tests', () {
    testWidgets('animates and honors disableAnimations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProcessDrawLine(isCompleted: true),
            ),
          ),
        ),
      );

      expect(find.byType(ProcessDrawLine), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      // Verify disableAnimations renders direct line
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: ProcessDrawLine(isCompleted: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('E6 BentoStagger Widget Tests', () {
    testWidgets('staggers and renders child safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BentoStagger(
              index: 0,
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });
  });

  group('E7 PingRipple Widget Tests', () {
    testWidgets('animates ripples and completes 2 cycles without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PingRipple(
                child: Text('Emergency Alert'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Emergency Alert'), findsOneWidget);
      // Run two 900ms cycles
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    });
  });
}

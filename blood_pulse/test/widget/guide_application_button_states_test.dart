import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/widgets/primary_button.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/guide_application_modal.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  group('GuideApplicationModal - 4 S1 PrimaryButton States', () {
    testWidgets('State 1: Apply Now shows active button', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createTestWidget(
        const GuideApplicationModal(
          overrideStatus: 'none',
          overrideButtonState: 'Apply Now',
          overrideCanApply: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Apply Now'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, 'Apply Now');
      expect(button.onPressed, isNotNull);
    });

    testWidgets('State 2: Pending review shows disabled button', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createTestWidget(
        const GuideApplicationModal(
          overrideStatus: 'pending',
          overrideButtonState: 'Pending review',
          overrideCanApply: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pending review'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, 'Pending review');
      expect(button.onPressed, isNull);
    });

    testWidgets('State 3: Approved (Manage) shows disabled button', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(createTestWidget(
        const GuideApplicationModal(
          overrideStatus: 'approved',
          overrideButtonState: 'Approved (Manage)',
          overrideCanApply: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Approved (Manage)'), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, 'Approved (Manage)');
      expect(button.onPressed, isNull);
    });

    testWidgets('State 4: Rejected shows date and disabled button', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      const stateText = 'Rejected (Apply again on 2026-11-05)';
      await tester.pumpWidget(createTestWidget(
        const GuideApplicationModal(
          overrideStatus: 'rejected',
          overrideButtonState: stateText,
          overrideCanApply: false,
          overrideReapplyDate: '2026-11-05',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(stateText), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, stateText);
      expect(button.onPressed, isNull);
    });
  });
}

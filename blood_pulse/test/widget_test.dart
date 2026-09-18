import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/main.dart';

void main() {
  testWidgets('App renders splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BloodPulseApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().contains('BloodPulse'),
      ),
      findsWidgets,
    );
    expect(find.text("Let's Start"), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/splash/splash_screen.dart';

void main() {
  testWidgets('App renders splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.contains('Blood Pulse') == true,
      ),
      findsWidgets,
    );
    expect(find.text('Get Started'), findsOneWidget);
  });
}


// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_calculators_screen.dart';

void main() {
  testWidgets('BMI Calculator updates to 22.9 when Height=175cm and Weight=70kg are entered',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HealthCalculatorsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial render
    expect(find.text('1. BMI & Weight Eligibility Calculator'), findsOneWidget);
    expect(find.text('Body Mass Index (BMI)'), findsOneWidget);

    // Locate the Height (cm) and Weight (kg) input fields
    final heightField = find.widgetWithText(TextField, '172');
    final weightField = find.widgetWithText(TextField, '68');

    // Enter Height = 175 and Weight = 70
    await tester.enterText(heightField, '175');
    await tester.pump();

    await tester.enterText(weightField, '70');
    await tester.pump();

    await tester.pumpAndSettle();

    // Verification: BMI formula (70 / (1.75 * 1.75)) = 22.857 -> 22.9
    expect(find.text('22.9'), findsOneWidget,
        reason: 'BMI must dynamically calculate and display 22.9 for 70kg / 175cm');
    expect(find.text('Normal Weight'), findsWidgets,
        reason: 'Category must reflect Normal Weight for BMI 22.9');
  });

  testWidgets('BMI Calculator handles negative and extreme values safely',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HealthCalculatorsScreen(),
        ),
      ),
    );

    final weightField = find.widgetWithText(TextField, '68');

    // Negative weight
    await tester.enterText(weightField, '-70');
    await tester.pumpAndSettle();

    expect(find.text('Invalid Input'), findsWidgets,
        reason: 'Negative weight must result in Invalid Input');

    // Extreme weight
    await tester.enterText(weightField, '900');
    await tester.pumpAndSettle();
    
    expect(find.text('Invalid Input'), findsWidgets,
        reason: 'Extreme weight must result in Invalid Input');
  });
}

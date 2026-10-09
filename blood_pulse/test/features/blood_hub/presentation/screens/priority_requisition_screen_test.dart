// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/priority_requisition_screen.dart';

void main() {
  testWidgets('PriorityBloodRequisitionScreen renders all form cards and submit button', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PriorityBloodRequisitionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Emergency Blood Request'), findsOneWidget);
    expect(find.text('Patient Details'), findsOneWidget);
    expect(find.text('Patient Photo (Optional)'), findsOneWidget);
    expect(find.text('Patient Name'), findsOneWidget);
    expect(find.text('Required Blood Type'), findsOneWidget);
    expect(find.text('Disease / Condition'), findsOneWidget);
    expect(find.text('Contact Number'), findsOneWidget);
    expect(find.text('Location & Urgency'), findsOneWidget);
    expect(find.text('Hospital Location'), findsOneWidget);
    expect(find.text('Medical Verification'), findsOneWidget);
    expect(find.text('Submit Request'), findsOneWidget);
  });

  testWidgets('PriorityBloodRequisitionScreen shows validation errors when submitted empty', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PriorityBloodRequisitionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Scroll to and tap Submit Request
    final submitFinder = find.text('Submit Request');
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Patient name is required'), findsOneWidget);
    expect(find.text('Condition is required'), findsOneWidget);
    expect(find.text('Contact number is required'), findsOneWidget);
  });

  testWidgets('PriorityBloodRequisitionScreen displays custom date time picker on Custom urgency', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PriorityBloodRequisitionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final customChipFinder = find.text('Custom');
    await tester.ensureVisible(customChipFinder);
    await tester.tap(customChipFinder);
    await tester.pumpAndSettle();

    expect(find.text('Select Required Date & Time'), findsOneWidget);
  });
}

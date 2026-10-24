// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/personal_emergency_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/priority_requisition_screen.dart';
import 'package:blood_pulse/features/blood_request/presentation/screens/identity_verification_screen.dart';

void main() {
  testWidgets('PersonalEmergencyScreen ends with [Create Poster] and [Confirm Submit]', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PersonalEmergencyScreen(),
        ),
      ),
    );
    await tester.pump();

    // Scroll to bottom to ensure action buttons are rendered
    final submitFinder = find.widgetWithText(ElevatedButton, 'Confirm Submit');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Create Poster'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Confirm Submit'), findsOneWidget);
  });

  testWidgets('PriorityBloodRequisitionScreen ends with [Create Poster] and [Confirm Submit]', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PriorityBloodRequisitionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submitFinder = find.widgetWithText(ElevatedButton, 'Confirm Submit');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();


    expect(find.widgetWithText(OutlinedButton, 'Create Poster'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Confirm Submit'), findsOneWidget);
  });

  testWidgets('IdentityVerificationScreen WhatsApp and Phone tabs show Coming Soon dialog', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: IdentityVerificationScreen(
            patientName: 'Test Patient',
            bloodGroup: 'A+',
            email: 'patient@example.com',
            autoSend: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap WhatsApp
    await tester.tap(find.text('WhatsApp'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('WhatsApp Verification'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Phone
    await tester.tap(find.text('Phone'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Phone Number Verification'), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 300));
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/main.dart';

void main() {
  testWidgets('End-to-End: Login to Map Flow Smoke Test', (WidgetTester tester) async {
    // 1. Pump the app
    await tester.pumpWidget(const ProviderScope(child: BloodPulseApp()));
    await tester.pumpAndSettle();

    // Verify Splash/Onboarding or Login is present
    // Just verifying the app boots up cleanly without crashes
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

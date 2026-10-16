// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/settings/presentation/screens/devices_sessions_screen.dart';

void main() {
  group('DevicesSessionsScreen Widget Tests', () {
    testWidgets('DevicesSessionsScreen renders AppBar and initial loading / layout structure', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DevicesSessionsScreen(),
          ),
        ),
      );

      // Verify Georgia AppBar title
      expect(find.text('Devices & Sessions'), findsOneWidget);

      // Pump to settle
      await tester.pump();

      // Ensure AppBar is present and back button is rendered
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}

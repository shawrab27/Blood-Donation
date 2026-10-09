// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/views/profile/profile_screen.dart';

void main() {
  testWidgets('ProfileScreen renders Admin-Locked Blood Group banner and avatar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('🔒 Note: Blood Group can ONLY be edited by an Admin', skipOffstage: false), findsOneWidget);
    expect(find.text('Requests Chart', skipOffstage: false), findsOneWidget);
    expect(find.text('User Posts Log', skipOffstage: false), findsOneWidget);
    expect(find.text('Donation History', skipOffstage: false), findsOneWidget);
  });
}

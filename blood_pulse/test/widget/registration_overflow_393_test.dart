// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/auth/presentation/screens/registration_screen.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';

void main() {
  testWidgets('Regression G-9 (W-2): Create Account screen does not overflow horizontally at 393px width', (tester) async {
    // Set viewport physical size to iPhone 13/14/15 width 393px
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegistrationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key elements are rendered without layout exceptions
    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Scroll down to verify the whole form at 393px width
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

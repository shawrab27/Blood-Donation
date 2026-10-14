// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/settings/presentation/screens/settings_screen.dart';
import 'package:blood_pulse/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:blood_pulse/core/widgets/profile_drawer.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/modals/delete_account_confirmation_modal.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/modals/logout_confirmation_modal.dart';

void main() {
  group('Settings & Profile Suite Tests', () {
    testWidgets('SettingsScreen renders UserCard, OptionsCard, and AccountActionsCard', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Donor Snapshot Card
      expect(find.textContaining('Blood Donor • Type'), findsOneWidget);

      // Options Card
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Notification Received'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Rate Us'), findsOneWidget);
      expect(find.text('Share App'), findsOneWidget);
      expect(find.text('Learn More'), findsOneWidget);
      expect(find.text('Contact Us'), findsOneWidget);

      // Danger / Account Actions Card
      expect(find.text('Create New Account'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('PrivacyPolicyScreen renders trust banner, clauses, and DPO email chip', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PrivacyPolicyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLINICAL INTEGRITY'), findsOneWidget);
      expect(find.text('Your Data Protects Lives'), findsOneWidget);
      expect(find.text('Core Governance Protocols'), findsOneWidget);
      expect(find.text('6 Clauses'), findsOneWidget);
      expect(find.text('privacy@bloodpulse.health'), findsOneWidget);
      expect(find.textContaining('Cryptographically Secured & Verified Transfusion Privacy Policy'), findsOneWidget);
    });

    testWidgets('DeleteAccountConfirmationModal renders impact stats and warning', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DeleteAccountConfirmationModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete Account?'), findsOneWidget);
      expect(find.textContaining('This action cannot be undone'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Yes, Delete'), findsOneWidget);
      expect(find.text('Donations'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Blood Pool'), findsOneWidget);
    });

    testWidgets('LogoutConfirmationModal renders safe session alert and actions', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LogoutConfirmationModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsNWidgets(2));
      expect(find.textContaining('Are you sure you want to logout?'), findsOneWidget);
      expect(find.text('VitalFlow Safe Session'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('ProfileDrawer renders branded header, theme selector, and menu list', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfileDrawer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT & PREFERENCES'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);
      expect(find.text('Appearance Theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Donate to BloodPulse'), findsOneWidget);
      expect(find.text('Inbox & Notifications'), findsOneWidget);
      expect(find.text('FAQ & Donor Guide'), findsOneWidget);
      expect(find.text('PulseAI'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Settings & Security'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    });
  });
}

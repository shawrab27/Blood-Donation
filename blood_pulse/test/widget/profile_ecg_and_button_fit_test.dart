// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:blood_pulse/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/profile_tabs_section.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';

void main() {
  group('Anomalies #4 & #5: Profile ECG line and Button Fit Tests', () {
    testWidgets('Profile tabs render ECG indicator in rounded container without clipping', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfileTabsSection(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Activity Summary'), findsOneWidget);
      expect(find.text('Donation History'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edit Profile screen Request Blood Group Change button does not overflow at text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              (ref) => ProfileNotifier()..state = AsyncValue.data(
                ProfileModel(
                  id: 1,
                  username: 'donor1',
                  firstName: 'Test',
                  lastName: 'User',
                  email: 'test@example.com',
                  bloodGroup: 'O+',
                  district: 'Dhaka',
                  phoneNumber: '+8801700000000',
                  isVerified: true,
                  isProfileComplete: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.3),
              ),
              child: const EditProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Request Blood Group Change'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('User profile Download Verified Certificate button does not overflow at text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              (ref) => ProfileNotifier()..state = AsyncValue.data(
                ProfileModel(
                  id: 1,
                  username: 'donor1',
                  firstName: 'Test',
                  lastName: 'User',
                  email: 'test@example.com',
                  bloodGroup: 'O+',
                  district: 'Dhaka',
                  phoneNumber: '+8801700000000',
                  totalBagsDonated: 3,
                  isVerified: true,
                  isProfileComplete: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: const UserProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.scrollUntilVisible(
        find.text('Download Verified Certificate'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Download Verified Certificate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

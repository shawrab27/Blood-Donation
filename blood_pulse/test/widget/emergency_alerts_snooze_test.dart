// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';

class _MockProfileNotifier extends ProfileNotifier {
  final ProfileModel? _initial;
  bool lastEnable = false;
  int? lastDays;

  _MockProfileNotifier(this._initial) : super();

  @override
  Future<void> fetchProfile() async {
    state = AsyncValue.data(_initial);
  }

  @override
  Future<bool> setSnooze({required bool enable, int? days, UserProfile? fallbackUser}) async {
    lastEnable = enable;
    lastDays = days;
    if (_initial != null) {
      final effectiveDays = days ?? 30;
      final updated = ProfileModel(
        id: _initial.id,
        username: _initial.username,
        firstName: _initial.firstName,
        lastName: _initial.lastName,
        bloodGroup: _initial.bloodGroup,
        totalBagsDonated: _initial.totalBagsDonated,
        isProfileComplete: _initial.isProfileComplete,
        alertPauseUntil: enable ? DateTime.now().add(Duration(days: effectiveDays)).toIso8601String() : null,
      );
      state = AsyncValue.data(updated);
    }
    return true;
  }
}

void main() {
  testWidgets('Snoozed profile shows Resume Alerts Now button and Change button', (tester) async {
    final pauseDate = DateTime.now().add(const Duration(days: 14));
    final notifier = _MockProfileNotifier(
      ProfileModel(
        id: 1,
        username: 'donor_snoozed',
        firstName: 'John',
        lastName: 'Doe',
        bloodGroup: 'B+',
        totalBagsDonated: 4,
        isProfileComplete: true,
        alertPauseUntil: pauseDate.toIso8601String(),
      ),
    );

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: UserProfileScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Pause Emergency Alerts is shown with Paused until date
    expect(find.text('Pause Emergency Alerts'), findsOneWidget);
    expect(find.textContaining('Paused until'), findsOneWidget);

    // Verify Resume Alerts Now button is present
    final resumeButton = find.text('Resume Alerts Now');
    expect(resumeButton, findsOneWidget);

    // Ensure visible then tap Resume Alerts Now
    await tester.ensureVisible(resumeButton);
    await tester.pumpAndSettle();
    await tester.tap(resumeButton);
    await tester.pumpAndSettle();

    expect(notifier.lastEnable, isFalse);
  });

  testWidgets('Tapping Change button opens duration bottom sheet with 1d, 3d, 7d, 30d, 90d', (tester) async {
    final pauseDate = DateTime.now().add(const Duration(days: 7));
    final notifier = _MockProfileNotifier(
      ProfileModel(
        id: 1,
        username: 'donor_snoozed',
        firstName: 'John',
        lastName: 'Doe',
        bloodGroup: 'B+',
        totalBagsDonated: 4,
        isProfileComplete: true,
        alertPauseUntil: pauseDate.toIso8601String(),
      ),
    );

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: UserProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final changeButton = find.text('Change');
    expect(changeButton, findsOneWidget);

    await tester.ensureVisible(changeButton);
    await tester.pumpAndSettle();
    await tester.tap(changeButton);
    await tester.pumpAndSettle();

    // Verify duration choices
    expect(find.text('1 Day (24 Hours)'), findsOneWidget);
    expect(find.text('3 Days'), findsOneWidget);
    expect(find.text('7 Days (1 Week)'), findsOneWidget);
    expect(find.text('30 Days (1 Month)'), findsOneWidget);
    expect(find.text('90 Days (3 Months)'), findsOneWidget);

    // Select 90 Days
    final option90 = find.text('90 Days (3 Months)');
    await tester.ensureVisible(option90);
    await tester.pumpAndSettle();
    await tester.tap(option90);
    await tester.pumpAndSettle();

    expect(notifier.lastEnable, isTrue);
    expect(notifier.lastDays, equals(90));
  });
}

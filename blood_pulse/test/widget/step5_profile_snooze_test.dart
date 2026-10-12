// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';

void main() {
  testWidgets('UserProfileScreen renders 30-day snooze switch tile directly after basic info', (tester) async {
    final testProfile = ProfileModel(
      id: 42,
      username: 'donor_hero',
      firstName: 'Sarah',
      lastName: 'Jenkins',
      bloodGroup: 'O+',
      totalBagsDonated: 5,
      isProfileComplete: true,
      alertPauseUntil: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => _FakeProfileNotifier(testProfile)),
        ],
        child: const MaterialApp(
          home: UserProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Basic Info Hero Card is rendered
    expect(find.text('Sarah Jenkins'), findsOneWidget);

    // Verify 30-day snooze switch tile is rendered
    expect(find.text('Pause Emergency Alerts'), findsOneWidget);
    expect(find.text('Receive emergency donation alerts in your area'), findsOneWidget);

    // Verify the Switch is currently false (not snoozed)
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final Switch switchWidget = tester.widget(switchFinder);
    expect(switchWidget.value, isFalse);
  });

  testWidgets('UserProfileScreen displays paused until date when alertPauseUntil is active', (tester) async {
    final pauseDate = DateTime.now().add(const Duration(days: 30));
    final testProfile = ProfileModel(
      id: 42,
      username: 'donor_hero',
      firstName: 'Sarah',
      lastName: 'Jenkins',
      bloodGroup: 'O+',
      totalBagsDonated: 5,
      isProfileComplete: true,
      alertPauseUntil: pauseDate.toIso8601String(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) => _FakeProfileNotifier(testProfile)),
        ],
        child: const MaterialApp(
          home: UserProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pause Emergency Alerts'), findsOneWidget);
    expect(find.textContaining('Paused until'), findsOneWidget);

    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final Switch switchWidget = tester.widget(switchFinder);
    expect(switchWidget.value, isTrue);
  });
}

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileModel? _initial;
  _FakeProfileNotifier(this._initial) : super();

  @override
  Future<void> fetchProfile() async {
    state = AsyncValue.data(_initial);
  }

  @override
  Future<bool> setSnooze({required bool enable}) async {
    if (_initial != null) {
      final updated = ProfileModel(
        id: _initial.id,
        username: _initial.username,
        firstName: _initial.firstName,
        lastName: _initial.lastName,
        bloodGroup: _initial.bloodGroup,
        totalBagsDonated: _initial.totalBagsDonated,
        isProfileComplete: _initial.isProfileComplete,
        alertPauseUntil: enable ? DateTime.now().add(const Duration(days: 30)).toIso8601String() : null,
      );
      state = AsyncValue.data(updated);
    }
    return true;
  }
}

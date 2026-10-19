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
  bool simulateFailure = false;

  _MockProfileNotifier(this._initial) : super();

  @override
  Future<void> fetchProfile() async {
    state = AsyncValue.data(_initial);
  }

  @override
  Future<bool> setSnooze({required bool enable, int? days, UserProfile? fallbackUser}) async {
    lastEnable = enable;
    lastDays = days;

    if (simulateFailure) {
      // Revert / do not change state on failure
      return false;
    }

    if (state.value != null) {
      final effectiveDays = days ?? 30;
      final newPauseUntil = enable
          ? DateTime.now().add(Duration(days: effectiveDays)).toIso8601String()
          : null;
      state = AsyncValue.data(state.value!.copyWith(
        alertPauseUntil: newPauseUntil,
        clearAlertPauseUntil: newPauseUntil == null,
      ));
    }
    return true;
  }
}

void main() {
  group('Task P-01: ProfileModel.copyWith and Snooze Nullability', () {
    test('ProfileModel.copyWith(alertPauseUntil: null) clears alertPauseUntil', () {
      final initial = ProfileModel(
        id: 1,
        username: 'test_donor',
        alertPauseUntil: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );
      expect(initial.isSnoozed, isTrue);

      final cleared = initial.copyWith(alertPauseUntil: null);
      expect(cleared.alertPauseUntil, isNull);
      expect(cleared.isSnoozed, isFalse);

      final explicitlyCleared = initial.copyWith(clearAlertPauseUntil: true);
      expect(explicitlyCleared.alertPauseUntil, isNull);
      expect(explicitlyCleared.isSnoozed, isFalse);
    });

    test('ProfileModel.copyWith preserves alertPauseUntil when omitted', () {
      final timestamp = DateTime.now().add(const Duration(days: 14)).toIso8601String();
      final initial = ProfileModel(
        id: 1,
        username: 'test_donor',
        alertPauseUntil: timestamp,
      );

      final updated = initial.copyWith(firstName: 'UpdatedName');
      expect(updated.alertPauseUntil, equals(timestamp));
      expect(updated.isSnoozed, isTrue);
    });
  });

  group('Task P-01: UserProfileScreen Snooze Widgets & Interactions', () {
    testWidgets('Snoozed profile shows full-size Resume Alerts Now button and remaining time label', (tester) async {
      final pauseDate = DateTime.now().add(const Duration(days: 14, hours: 2));
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

      // Verify Pause Emergency Alerts header and dynamic remaining time label
      expect(find.text('Pause Emergency Alerts'), findsOneWidget);
      expect(find.textContaining('14 days remaining'), findsOneWidget);

      // Verify Resume Alerts Now button is present and full-size
      final resumeButtonFinder = find.widgetWithText(ElevatedButton, 'Resume Alerts Now');
      expect(resumeButtonFinder, findsOneWidget);

      // Tap Resume Alerts Now
      await tester.ensureVisible(resumeButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(resumeButtonFinder);
      await tester.pumpAndSettle();

      // Verify snooze was turned off
      expect(notifier.lastEnable, isFalse);
      expect(notifier.state.value!.isSnoozed, isFalse);
      expect(notifier.state.value!.alertPauseUntil, isNull);

      // UI updates to unsnoozed state
      expect(find.text('Receive emergency donation alerts in your area'), findsOneWidget);
      expect(find.text('Resume Alerts Now'), findsNothing);
    });

    testWidgets('Switch can toggle snooze off directly', (tester) async {
      final pauseDate = DateTime.now().add(const Duration(days: 30));
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

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);

      // Tap switch to turn OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(notifier.lastEnable, isFalse);
      expect(notifier.state.value!.alertPauseUntil, isNull);
      expect(notifier.state.value!.isSnoozed, isFalse);
    });

    testWidgets('Tapping Change Duration opens sheet with days and months options', (tester) async {
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

      final changeButton = find.text('Change Pause Duration');
      expect(changeButton, findsOneWidget);

      await tester.ensureVisible(changeButton);
      await tester.pumpAndSettle();
      await tester.tap(changeButton);
      await tester.pumpAndSettle();

      // Verify duration choices include days and months
      expect(find.text('1 Day (24 Hours)'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      expect(find.text('7 Days (1 Week)'), findsOneWidget);
      expect(find.text('30 Days (1 Month)'), findsOneWidget);
      expect(find.text('60 Days (2 Months)'), findsOneWidget);
      expect(find.text('90 Days (3 Months)'), findsOneWidget);

      // Select 60 Days
      final option60 = find.text('60 Days (2 Months)');
      await tester.ensureVisible(option60);
      await tester.pumpAndSettle();
      await tester.tap(option60);
      await tester.pumpAndSettle();

      expect(notifier.lastEnable, isTrue);
      expect(notifier.lastDays, equals(60));
    });

    testWidgets('API failure triggers error rollback and keeps previous snooze state', (tester) async {
      final initialTimestamp = DateTime.now().add(const Duration(days: 10)).toIso8601String();
      final notifier = _MockProfileNotifier(
        ProfileModel(
          id: 1,
          username: 'donor_snoozed',
          firstName: 'John',
          lastName: 'Doe',
          bloodGroup: 'B+',
          totalBagsDonated: 4,
          isProfileComplete: true,
          alertPauseUntil: initialTimestamp,
        ),
      );
      notifier.simulateFailure = true;

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

      final resumeButton = find.text('Resume Alerts Now');
      await tester.ensureVisible(resumeButton);
      await tester.pumpAndSettle();
      await tester.tap(resumeButton);
      await tester.pumpAndSettle();

      // State rolled back / remained snoozed
      expect(notifier.state.value!.isSnoozed, isTrue);
      expect(notifier.state.value!.alertPauseUntil, equals(initialTimestamp));
      expect(find.text('Could not resume alerts.'), findsOneWidget);
    });

    testWidgets('Responsive overflow sweep at textScale 1.3 across screen widths', (tester) async {
      final screenWidths = [320.0, 360.0, 412.0];
      final pauseDate = DateTime.now().add(const Duration(days: 14));

      for (final width in screenWidths) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;

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

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith((ref) => notifier),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: const UserProfileScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check for no overflows
        expect(tester.takeException(), isNull, reason: 'Overflow occurred on width $width with textScale 1.3');
        expect(find.text('Pause Emergency Alerts'), findsOneWidget);
        expect(find.text('Resume Alerts Now'), findsOneWidget);
        expect(find.text('Change Pause Duration'), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
    });
  });
}

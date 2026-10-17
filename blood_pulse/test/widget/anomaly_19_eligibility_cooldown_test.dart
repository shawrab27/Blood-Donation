// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/health_hub/presentation/providers/health_calculators_provider.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/calculators/cooldown_countdown_card.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfileNotifier extends ProfileNotifier {
  FakeProfileNotifier(ProfileModel? initial) : super() {
    state = AsyncValue.data(initial);
  }

  @override
  Future<void> fetchProfile() async {}
}

ProfileModel createSampleProfile({
  required int totalBagsDonated,
  String? lastDonationDate,
}) {
  return ProfileModel(
    id: 1,
    firstName: 'Test',
    lastName: 'Donor',
    totalBagsDonated: totalBagsDonated,
    bagsDonated: totalBagsDonated,
    lastDonationDate: lastDonationDate,
    rank: 1,
    globalRank: 1,
    badge: 'Newcomer',
    ratingAvg: 5.0,
    ratingCount: 1,
    xp: 100,
    level: 1,
    levelProgress: 0.5,
    nextLevelXp: 200,
    userIntent: 'DONOR',
    isAvailable: true,
    isVerified: true,
    isProfileComplete: true,
    missingFields: const [],
    showInRankings: true,
    showContact: true,
    publicProfile: true,
    notificationsEnabled: true,
    emergencyAlertsEnabled: true,
    daysLeft: 0,
    isEligible: true,
    donationHistory: const [],
    recentLogs: const [],
  );
}

void main() {
  group('Anomaly #19: Dynamic Eligibility & Cooldown from Profile Tests', () {
    test('Zero donations or null last donation date defaults to eligible now (0 days cooldown)', () {
      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(
            (ref) => FakeProfileNotifier(createSampleProfile(totalBagsDonated: 0, lastDonationDate: null)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(healthCalculatorsProvider);
      expect(state.cooldownDaysRemaining, equals(0));
      expect(state.isCooldownEligible, isTrue);
    });

    test('Recent donation (30 days ago) calculates exact remaining cooldown (60 days)', () {
      final donationDate = DateTime.now().subtract(const Duration(days: 30));
      final dateStr = donationDate.toIso8601String().split('T')[0];

      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(
            (ref) => FakeProfileNotifier(createSampleProfile(totalBagsDonated: 2, lastDonationDate: dateStr)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(healthCalculatorsProvider);
      expect(state.cooldownDaysRemaining, closeTo(60, 1));
      expect(state.isCooldownEligible, isFalse);
    });

    testWidgets('CooldownCountdownCard renders Eligible to Donate Today for 0 donation donors', (tester) async {
      const state = HealthCalculatorState(
        heightCm: 170,
        weightKg: 65,
        systolicBp: 120,
        diastolicBp: 80,
        pulseRateBpm: 72,
        hemoglobinLevel: 14.0,
        hydrationMl: 1500,
        lastDonationDate: null,
        historyLogs: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CooldownCountdownCard(
              state: state,
              onDateSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eligible to Donate Today!'), findsOneWidget);
      expect(find.textContaining('49 Days'), findsNothing);
      expect(find.textContaining('43 Days'), findsNothing);
    });
  });
}

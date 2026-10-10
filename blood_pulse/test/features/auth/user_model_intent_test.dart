// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/models/user_model.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';

void main() {
  group('Step 1 Auth & Roles Intent Tests', () {
    test('UserModel default intent is DONATE_AND_REQUEST and can donate', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Test Donor',
        email: 'donor@example.com',
        phonePrimary: '+8801711111111',
        role: 'Civilian',
        division: 'Dhaka',
        district: 'Dhaka',
        upazila: 'Dhanmondi',
        bloodGroup: 'O+',
        lastDonationDate: DateTime.now().subtract(const Duration(days: 100)),
      );

      expect(user.userIntent, equals('DONATE_AND_REQUEST'));
      expect(user.canDonate, isTrue);
      expect(user.isEligibleToDonate, isTrue);
      expect(user.cooldownDaysRemaining, equals(0));
    });

    test('UserModel with ONLY_REQUEST intent never donates and bypasses cooldown timer', () {
      final user = UserModel(
        uid: 'u2',
        name: 'Request Only User',
        email: 'req@example.com',
        phonePrimary: '+8801722222222',
        role: 'Civilian',
        division: 'Dhaka',
        district: 'Dhaka',
        upazila: 'Dhanmondi',
        bloodGroup: 'B+',
        lastDonationDate: DateTime.now().subtract(const Duration(days: 10)), // Recently donated date if any
        userIntent: 'ONLY_REQUEST',
      );

      expect(user.userIntent, equals('ONLY_REQUEST'));
      expect(user.canDonate, isFalse);
      expect(user.isEligibleToDonate, isFalse);
      // Cooldown timer is bypassed (0 days)
      expect(user.cooldownDaysRemaining, equals(0));

      final mapped = user.toMap();
      expect(mapped['user_intent'], equals('ONLY_REQUEST'));

      final restored = UserModel.fromMap(mapped);
      expect(restored.userIntent, equals('ONLY_REQUEST'));
      expect(restored.canDonate, isFalse);
    });

    test('UserProfile in AuthNotifier supports ONLY_REQUEST intent', () {
      final profile = UserProfile(
        fullName: 'Requester Only',
        email: 'req@example.com',
        primaryPhone: '+8801733333333',
        age: 30,
        gender: 'Female',
        bloodGroup: 'A+',
        category: 'civilian',
        categoryDetails: {'district': 'Dhaka'},
        neverDonated: true,
        totalBagsDonated: 0,
        userIntent: 'ONLY_REQUEST',
      );

      expect(profile.isOnlyRequest, isTrue);
      expect(profile.canDonate, isFalse);

      final copy = profile.copyWith(userIntent: 'DONATE_AND_REQUEST');
      expect(copy.isOnlyRequest, isFalse);
      expect(copy.canDonate, isTrue);
    });
  });
}

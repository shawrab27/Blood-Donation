import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/models/user_model.dart';
import 'package:blood_pulse/providers/profile_countdown_provider.dart';

void main() {
  group('120-Day Donation Countdown Unit Tests', () {
    test('User with null lastDonationDate is immediately eligible', () {
      const user = UserModel(
        uid: 'usr_1',
        name: 'Test Donor',
        email: 'test@bloodpulse.org',
        phonePrimary: '+880 1700-000000',
        role: 'Civilian',
        division: 'Dhaka',
        district: 'Dhaka',
        upazila: 'Uttara',
        bloodGroup: 'A+',
      );

      expect(user.isEligibleToDonate, isTrue);
      expect(user.cooldownDaysRemaining, equals(0));
    });

    test('User with donation 46 days ago has 74 days remaining', () {
      final donationDate = DateTime.now().subtract(const Duration(days: 46));
      final user = UserModel(
        uid: 'usr_2',
        name: 'Test Donor 2',
        email: 'test2@bloodpulse.org',
        phonePrimary: '+880 1700-111111',
        role: 'Student',
        division: 'Dhaka',
        district: 'Dhaka',
        upazila: 'Dhanmondi',
        bloodGroup: 'O+',
        lastDonationDate: donationDate,
      );

      expect(user.isEligibleToDonate, isFalse);
      expect(user.cooldownDaysRemaining, closeTo(74, 1));
    });

    test('ProfileCountdownState daysRemaining getter', () {
      final donationDate = DateTime.now().subtract(const Duration(days: 120));
      final user = UserModel(
        uid: 'usr_3',
        name: 'Eligible Donor',
        email: 'test3@bloodpulse.org',
        phonePrimary: '+880 1700-222222',
        role: 'Civilian',
        division: 'Dhaka',
        district: 'Dhaka',
        upazila: 'Mirpur',
        bloodGroup: 'B+',
        lastDonationDate: donationDate,
      );

      final state = ProfileCountdownState(user: user);
      expect(state.daysRemaining, equals(0));
      expect(state.isReadyToDonate, isTrue);
    });
  });
}

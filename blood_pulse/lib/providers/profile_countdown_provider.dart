import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class ProfileCountdownState {
  const ProfileCountdownState({
    this.user,
    this.errorMessage,
  });

  final UserModel? user;
  final String? errorMessage;

  int get daysRemaining {
    if (user?.lastDonationDate == null) return 0;
    final nextEligible = user!.lastDonationDate!.add(const Duration(days: 120));
    final diff = nextEligible.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isReadyToDonate => daysRemaining == 0;

  ProfileCountdownState copyWith({
    UserModel? user,
    String? errorMessage,
  }) {
    return ProfileCountdownState(
      user:         user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class ProfileCountdownNotifier extends StateNotifier<ProfileCountdownState> {
  ProfileCountdownNotifier()
      : super(
          ProfileCountdownState(
            user: UserModel(
              uid: 'usr_101',
              name: 'Blood Donor',
              email: 'donor@bloodpulse.org',
              phonePrimary: '+880 1700-000000',
              role: 'Altruist',
              institution: 'BloodPulse Community',
              division: 'Dhaka',
              district: 'Dhaka',
              upazila: 'Dhanmondi',
              bloodGroup: 'O+',
              adminLocked: true,
              lastDonationDate: DateTime.now().subtract(const Duration(days: 46)),
              badgeTier: 'Golden',
            ),
          ),
        );

  /// Synchronizes countdown user model with currently authenticated UserProfile
  void syncWithAuthUser(String? name, String? email, String? bloodGroup, String? phone) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(
          name: (name != null && name.isNotEmpty) ? name : state.user!.name,
          email: (email != null && email.isNotEmpty) ? email : state.user!.email,
          phonePrimary: (phone != null && phone.isNotEmpty) ? phone : state.user!.phonePrimary,
          bloodGroup: (bloodGroup != null && bloodGroup.isNotEmpty) ? bloodGroup : state.user!.bloodGroup,
        ),
      );
    }
  }

  /// Attempts to update user blood group, enforcing the Admin-Lock security rule.
  bool updateBloodGroup(String newBloodGroup, {bool isAdmin = false}) {
    if (state.user?.adminLocked == true && !isAdmin) {
      state = state.copyWith(
        errorMessage: '🔒 Security Violation: Blood group is locked. Contact BloodPulse Admin to modify.',
      );
      return false;
    }

    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(bloodGroup: newBloodGroup),
        errorMessage: null,
      );
    }
    return true;
  }

  /// Updates last donation date and recalculates 120-day countdown.
  void recordDonation(DateTime donationDate) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(lastDonationDate: donationDate),
      );
    }
  }
}

final profileCountdownProvider = StateNotifierProvider<ProfileCountdownNotifier, ProfileCountdownState>((ref) {
  return ProfileCountdownNotifier();
});

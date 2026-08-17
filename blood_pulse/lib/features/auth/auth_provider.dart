import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';

// Simulates a logged-in user state
class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier() : super(null);

  void login(String phone) {
    // Simulated successful login state
    state = UserModel(
      uid: 'simulated_user_123',
      name: 'John Doe',
      phone: phone,
      bloodGroup: 'O+',
      district: 'Dhaka',
      upazila: 'Savar',
      nidNumber: '12345678901234567',
    );
  }

  void logout() {
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});

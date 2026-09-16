import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../services/api_client.dart';

/// Authentication status for BloodPulse.
enum AuthStatus { unauthenticated, loading, authenticated, error }

/// Represents registration info for a user.
class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.primaryPhone,
    this.secondaryPhone,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.category, // 'student' or 'civilian'
    required this.categoryDetails,
    required this.neverDonated,
    this.lastDonationDate,
    required this.totalBagsDonated,
    this.isOtpVerified = false,
    this.isProfileComplete = false,
    this.nidHash,
  });

  final String fullName;
  final String email;
  final String primaryPhone;
  final String? secondaryPhone;
  final int age;
  final String gender;
  final String bloodGroup;
  final String category;
  final Map<String, String> categoryDetails;
  final bool neverDonated;
  final DateTime? lastDonationDate;
  final int totalBagsDonated;
  final bool isOtpVerified;
  final bool isProfileComplete;
  final String? nidHash;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? primaryPhone,
    String? secondaryPhone,
    int? age,
    String? gender,
    String? bloodGroup,
    String? category,
    Map<String, String>? categoryDetails,
    bool? neverDonated,
    DateTime? lastDonationDate,
    int? totalBagsDonated,
    bool? isOtpVerified,
    bool? isProfileComplete,
    String? nidHash,
  }) {
    return UserProfile(
      fullName:         fullName         ?? this.fullName,
      email:            email            ?? this.email,
      primaryPhone:     primaryPhone     ?? this.primaryPhone,
      secondaryPhone:   secondaryPhone   ?? this.secondaryPhone,
      age:              age              ?? this.age,
      gender:           gender           ?? this.gender,
      bloodGroup:       bloodGroup       ?? this.bloodGroup,
      category:         category         ?? this.category,
      categoryDetails:  categoryDetails  ?? this.categoryDetails,
      neverDonated:     neverDonated     ?? this.neverDonated,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      totalBagsDonated: totalBagsDonated ?? this.totalBagsDonated,
      isOtpVerified:    isOtpVerified    ?? this.isOtpVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      nidHash:          nidHash          ?? this.nidHash,
    );
  }
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? errorMessage,
  }) {
    return AuthState(
      status:       status       ?? this.status,
      user:         user         ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        super(const AuthState());

  /// Login using ApiClient.login(identifier, password).
  Future<bool> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      await _apiClient.login(identifier, password);

      final user = state.user ??
          UserProfile(
            fullName: 'Donor User',
            email: '',
            primaryPhone: identifier,
            age: 25,
            gender: 'Male',
            bloodGroup: 'O+',
            category: 'civilian',
            categoryDetails: {},
            neverDonated: true,
            totalBagsDonated: 0,
            isOtpVerified: true,
          );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    }
  }

  /// Initiates Google OAuth Sign-In flow, sends tokens to Django backend,
  /// retrieves JWT tokens and persists them via ApiClient (FlutterSecureStorage).
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        // User aborted the sign in dialog
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final accessToken = auth.accessToken ?? auth.idToken ?? '';

      final authData = await _apiClient.loginWithGoogle(
        accessToken: accessToken,
        idToken: auth.idToken,
        email: account.email,
        displayName: account.displayName,
      );

      final userData = authData['user'] as Map<String, dynamic>?;
      final bool isProfileComplete = userData?['is_profile_complete'] == true;

      final user = UserProfile(
        fullName: account.displayName ?? 'Google Donor',
        email: account.email,
        primaryPhone: userData?['phone_number'] ?? '',
        age: 25,
        gender: 'Not specified',
        bloodGroup: userData?['blood_group'] ?? '',
        category: 'civilian',
        categoryDetails: {
          'district': userData?['district'] ?? 'Dhaka',
        },
        neverDonated: true,
        totalBagsDonated: 0,
        isOtpVerified: true,
        isProfileComplete: isProfileComplete,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    }
  }

  /// Alias for signInWithGoogle
  Future<bool> loginWithGoogle() => signInWithGoogle();

  /// Sets the user profile upon registration and posts to `/api/donors/`.
  Future<bool> registerUser(UserProfile profile) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null, user: profile);

    final district = profile.categoryDetails['district'] ??
        profile.categoryDetails['division'] ??
        'Dhaka';

    final payload = {
      'blood_group': profile.bloodGroup,
      'district': district,
      'phone_number': profile.primaryPhone,
      if (profile.nidHash != null && profile.nidHash!.isNotEmpty)
        'nid_hash': profile.nidHash,
      'last_donation_date': profile.lastDonationDate?.toIso8601String().split('T').first,
      'is_verified': profile.isOtpVerified,
      'full_name': profile.fullName,
      'email': profile.email,
      'age': profile.age,
      'gender': profile.gender,
      'category': profile.category,
    };

    try {
      final response = await _apiClient.post('donors/', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: profile,
          errorMessage: null,
        );
        return true;
      } else {
        final errorMsg = _extractErrorMessage(response.body);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: errorMsg,
        );
        return false;
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    }
  }

  /// Set authenticated status directly (for skip bypass or successful OTP verify).
  void authenticateDirectly({required bool isOtpVerified}) {
    if (state.user != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: state.user!.copyWith(isOtpVerified: isOtpVerified),
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: UserProfile(
          fullName: 'Guest Altruist',
          email: 'guest@bloodpulse.org',
          primaryPhone: '+8801700000000',
          age: 20,
          gender: 'Male',
          bloodGroup: 'O+',
          category: 'civilian',
          categoryDetails: {},
          neverDonated: true,
          totalBagsDonated: 0,
          isOtpVerified: isOtpVerified,
        ),
      );
    }
  }

  /// Verification status update (e.g. from JIT verification)
  void setOtpVerified(bool verified) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(isOtpVerified: verified),
      );
    }
  }


  /// Social authentication (Facebook)
  Future<bool> loginWithFacebook() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final user = UserProfile(
        fullName: 'Facebook Altruist',
        email: 'donor@facebook.com',
        primaryPhone: '+8801800000002',
        age: 26,
        gender: 'Female',
        bloodGroup: 'A+',
        category: 'civilian',
        categoryDetails: const {'provider': 'Facebook'},
        neverDonated: false,
        totalBagsDonated: 2,
        isOtpVerified: true,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to sign in with Facebook: $e',
      );
      return false;
    }
  }

  void logout() {
    _apiClient.clearTokens();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        if (decoded.containsKey('detail')) return decoded['detail'].toString();
        if (decoded.containsKey('error')) return decoded['error'].toString();
        if (decoded.containsKey('message')) return decoded['message'].toString();
        return decoded.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      }
      return body;
    } catch (_) {
      return body.isNotEmpty ? body : 'Server error occurred.';
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

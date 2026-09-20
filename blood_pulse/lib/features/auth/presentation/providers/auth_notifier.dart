import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
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
    this.isEmailVerified = false,
    this.nidHash,
    this.photoUrl,
    this.avatarBytes,
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
  final bool isEmailVerified;
  final String? nidHash;
  final String? photoUrl;
  final Uint8List? avatarBytes;

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
    bool? isEmailVerified,
    String? nidHash,
    String? photoUrl,
    Uint8List? avatarBytes,
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
      isEmailVerified:  isEmailVerified  ?? this.isEmailVerified,
      nidHash:          nidHash          ?? this.nidHash,
      photoUrl:         photoUrl         ?? this.photoUrl,
      avatarBytes:      avatarBytes      ?? this.avatarBytes,
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

  AuthNotifier({ApiClient? apiClient, AuthState? initialState})
      : _apiClient = apiClient ?? ApiClient(),
        super(initialState ?? const AuthState());

  /// Sets user state directly for testing
  @visibleForTesting
  void setUserForTesting(UserProfile user) {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

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
      debugPrint('[GoogleSignIn] ▶ Starting Google Sign-In flow...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      debugPrint('[GoogleSignIn] Calling googleSignIn.signIn()...');
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        // User aborted the sign in dialog
        debugPrint('[GoogleSignIn] ✗ User cancelled sign-in dialog.');
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }
      debugPrint('[GoogleSignIn] ✓ Got account: ${account.email}');

      debugPrint('[GoogleSignIn] Getting Google auth tokens...');
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      debugPrint('[GoogleSignIn] accessToken present: ${googleAuth.accessToken != null}');
      debugPrint('[GoogleSignIn] idToken present: ${googleAuth.idToken != null}');

      // Authenticate with Firebase using Google credentials
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('[GoogleSignIn] Calling FirebaseAuth.signInWithCredential...');
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        debugPrint('[GoogleSignIn] ✗ FirebaseAuth returned null user.');
        throw ApiException('Failed to retrieve Firebase user profile.');
      }
      debugPrint('[GoogleSignIn] ✓ Firebase user: ${firebaseUser.email}, uid: ${firebaseUser.uid}');

      debugPrint('[GoogleSignIn] Fetching Firebase ID token...');
      final String? firebaseIdToken = await firebaseUser.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        debugPrint('[GoogleSignIn] ✗ Firebase ID token is null/empty.');
        throw ApiException('Failed to retrieve Firebase ID token.');
      }
      debugPrint('[GoogleSignIn] ✓ Firebase ID token obtained (${firebaseIdToken.length} chars)');

      // Exchange token with backend: Try Firebase first, fallback to Google endpoint
      Map<String, dynamic> authData;
      try {
        debugPrint('[GoogleSignIn] Calling backend /api/auth/firebase/ ...');
        authData = await _apiClient.loginWithFirebase(
          idToken: firebaseIdToken,
          email: firebaseUser.email ?? account.email,
          displayName: firebaseUser.displayName ?? account.displayName,
        );
      } catch (fbErr) {
        debugPrint('[GoogleSignIn] Firebase backend failed ($fbErr), trying /api/auth/google/ fallback...');
        authData = await _apiClient.loginWithGoogle(
          accessToken: googleAuth.accessToken ?? '',
          idToken: googleAuth.idToken,
          email: firebaseUser.email ?? account.email,
          displayName: firebaseUser.displayName ?? account.displayName,
        );
      }
      debugPrint('[GoogleSignIn] ✓ Backend returned: ${authData.keys.toList()}');

      final userData = authData['user'] as Map<String, dynamic>?;
      final String? photoUrl = firebaseUser.photoURL ?? account.photoUrl;
      final bloodGroup = (userData?['blood_group'] as String?) ?? '';
      final phoneNumber = (userData?['phone_number'] as String?) ?? '';
      final bool isProfileComplete = userData?['is_profile_complete'] == true ||
          (bloodGroup.isNotEmpty && phoneNumber.isNotEmpty);

      final user = UserProfile(
        fullName: firebaseUser.displayName ?? account.displayName ?? 'Google Donor',
        email: firebaseUser.email ?? account.email,
        primaryPhone: phoneNumber,
        age: 25,
        gender: 'Not specified',
        bloodGroup: bloodGroup,
        category: 'civilian',
        categoryDetails: {
          'district': userData?['district'] ?? 'Dhaka',
        },
        neverDonated: true,
        totalBagsDonated: 0,
        isOtpVerified: true,
        isProfileComplete: isProfileComplete,
        photoUrl: photoUrl,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      debugPrint('[GoogleSignIn] ✓ Sign-in complete. isProfileComplete: $isProfileComplete');
      return true;
    } catch (e) {
      debugPrint('[GoogleSignIn] ✗ ERROR: $e');
      debugPrint('[GoogleSignIn] Error type: ${e.runtimeType}');
      String msg = e.toString().replaceAll('Exception: ', '');
      if (kIsWeb && msg.contains('Null check operator')) {
        msg = 'Google Sign-In on Web requires a Google Cloud Web Client ID. Please test Google Sign-In on your mobile device (flutter run), or log in with Username/Password.';
      }
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
    final completeProfile = profile.copyWith(isProfileComplete: true);
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null, user: completeProfile);

    final district = completeProfile.categoryDetails['district'] ??
        completeProfile.categoryDetails['division'] ??
        'Dhaka';

    final payload = {
      'blood_group': completeProfile.bloodGroup,
      'district': district,
      'phone_number': completeProfile.primaryPhone,
      if (completeProfile.nidHash != null && completeProfile.nidHash!.isNotEmpty)
        'nid_hash': completeProfile.nidHash,
      'last_donation_date': completeProfile.lastDonationDate?.toIso8601String().split('T').first,
      'is_verified': completeProfile.isOtpVerified,
      'full_name': completeProfile.fullName,
      'email': completeProfile.email,
      'age': completeProfile.age,
      'gender': completeProfile.gender,
      'category': completeProfile.category,
    };

    try {
      final response = await _apiClient.post('donors/', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: completeProfile,
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
        user: state.user!.copyWith(
          isOtpVerified: isOtpVerified,
          isProfileComplete: true,
        ),
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
          isProfileComplete: true,
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

  /// Checks whether user profile is complete from backend GET /api/profile/completion-status/
  Future<bool> checkProfileCompletion() async {
    try {
      final res = await _apiClient.get('profile/completion-status/');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final isComplete = data['is_complete'] == true;
        final isEmailVerified = data['email_verified'] == true;
        if (state.user != null) {
          state = state.copyWith(
            user: state.user!.copyWith(
              isProfileComplete: isComplete,
              isEmailVerified: isEmailVerified,
            ),
          );
        }
        return isComplete;
      }
      return state.user?.isProfileComplete ?? false;
    } catch (e) {
      debugPrint('[AuthNotifier] checkProfileCompletion error: $e');
      return state.user?.isProfileComplete ?? false;
    }
  }

  /// Sends 6-digit email verification OTP via backend POST /api/auth/send-verification-email/
  Future<bool> sendVerificationEmail({String? email}) async {
    try {
      final targetEmail = email ?? state.user?.email ?? '';
      final response = await _apiClient.post(
        'auth/send-verification-email/',
        body: {'email': targetEmail},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      final err = _extractErrorMessage(response.body);
      state = state.copyWith(errorMessage: err);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to send verification code: $e');
      return false;
    }
  }

  /// Verifies 6-digit email OTP via backend POST /api/auth/verify-email-code/
  Future<bool> verifyEmailCode({required String code, String? email}) async {
    try {
      final payload = {
        'code': code.trim(),
        if (email != null && email.isNotEmpty) 'email': email.trim(),
      };
      final response = await _apiClient.post(
        'auth/verify-email-code/',
        body: payload,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (state.user != null) {
          state = state.copyWith(
            user: state.user!.copyWith(
              isEmailVerified: true,
              email: email ?? state.user!.email,
            ),
            errorMessage: null,
          );
        }
        return true;
      }
      final err = _extractErrorMessage(response.body);
      state = state.copyWith(errorMessage: err);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Verification failed: $e');
      return false;
    }
  }

  /// Local manual setter for email verification status
  void setEmailVerified(bool verified) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(isEmailVerified: verified),
      );
    }
  }

  /// Explicitly update the completed profile fields and mark profile complete
  void updateCompletedProfile({
    required String bloodGroup,
    required String district,
    required String phone,
  }) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(
          bloodGroup: bloodGroup,
          primaryPhone: phone,
          isProfileComplete: true,
          categoryDetails: {
            ...state.user!.categoryDetails,
            'district': district,
          },
        ),
      );
    }
  }

  /// Updates local avatar bytes for instant preview and app-wide sync
  void updateAvatar(Uint8List avatarBytes) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(avatarBytes: avatarBytes),
      );
    }
  }

  /// Updates user full name
  void updateProfileName(String fullName) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(fullName: fullName),
      );
    }
  }

  void logout() {
    _apiClient.clearTokens();
    state = const AuthState();
  }

  Future<bool> deleteAccount({void Function(String error)? onError}) async {
    try {
      final response = await _apiClient.delete('donors/me/');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        logout();
        return true;
      } else {
        final err = _extractErrorMessage(response.body);
        onError?.call(err);
        return false;
      }
    } catch (e) {
      onError?.call('Error deleting account: $e');
      return false;
    }
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

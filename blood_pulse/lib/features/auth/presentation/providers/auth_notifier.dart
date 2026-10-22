import '../../../../features/profile/domain/providers/profile_provider.dart';
import '../../../../core/access/access_guard.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/api_client.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/tracking_service.dart';
import '../../../../services/fcm_service.dart';

/// Authentication status for BloodPulse.
enum AuthStatus { unauthenticated, loading, authenticated, authenticatedIncomplete, error }

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
    this.missingFields = const [],
    this.isEmailVerified = false,
    this.nidHash,
    this.photoUrl,
    this.avatarBytes,
    this.googlePhotoUrl,
    this.authProvider,
    this.userIntent = 'DONATE_AND_REQUEST',
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
  final List<String> missingFields;
  final bool isEmailVerified;
  final String? nidHash;
  final String? photoUrl;
  final Uint8List? avatarBytes;
  final String? googlePhotoUrl;
  final String? authProvider;
  final String userIntent; // 'DONATE_AND_REQUEST' or 'ONLY_REQUEST'

  bool get isOnlyRequest => userIntent == 'ONLY_REQUEST';
  bool get canDonate => userIntent != 'ONLY_REQUEST';

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
    List<String>? missingFields,
    bool? isEmailVerified,
    String? nidHash,
    String? photoUrl,
    Uint8List? avatarBytes,
    String? googlePhotoUrl,
    String? authProvider,
    String? userIntent,
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
      missingFields:    missingFields    ?? this.missingFields,
      isEmailVerified:  isEmailVerified  ?? this.isEmailVerified,
      nidHash:          nidHash          ?? this.nidHash,
      photoUrl:         photoUrl         ?? this.photoUrl,
      avatarBytes:      avatarBytes      ?? this.avatarBytes,
      googlePhotoUrl:   googlePhotoUrl   ?? this.googlePhotoUrl,
      authProvider:     authProvider     ?? this.authProvider,
      userIntent:       userIntent       ?? this.userIntent,
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


class AuthNotifier extends Notifier<AuthState> {
  final ApiClient _apiClient;
  final AuthState? _initialState;

  AuthNotifier({ApiClient? apiClient, AuthState? initialState})
      : _apiClient = apiClient ?? ApiClient(),
        _initialState = initialState;

  @override
  AuthState build() {
    ApiClient.onSessionExpired = () {
      if (state.status != AuthStatus.unauthenticated) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          errorMessage: 'Session expired. Please log in again.',
        );
      }
    };
    final cached = ApiClient.cachedAccessToken;
    final hasStoredToken = cached != null && cached.isNotEmpty;
    return _initialState ?? AuthState(
      status: hasStoredToken ? AuthStatus.loading : AuthStatus.unauthenticated,
    );
  }

  /// Restores session on app startup by validating stored token and fetching /api/profile/me/
  Future<void> restoreSession() async {
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      return;
    }

    try {
      var token = await _apiClient.getAccessToken();
      final refresh = await _apiClient.getRefreshToken();

      // If neither access nor refresh token exists, user is unauthenticated
      if ((token == null || token.isEmpty) && (refresh == null || refresh.isEmpty)) {
        state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
        return;
      }

      state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

      // If access token is missing but a valid refresh token exists, refresh first
      if (token == null || token.isEmpty) {
        token = await _apiClient.refreshToken();
        if (token == null || token.isEmpty) {
          // Check if refresh token was cleared because of a 401
          final stillRefresh = await _apiClient.getRefreshToken();
          if (stillRefresh == null || stillRefresh.isEmpty) {
            state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
            return;
          }
          // Refresh failed due to network / gateway - preserve session offline
          await _loadOfflineCachedProfile();
          return;
        }
      }

      final response = await _apiClient.get('profile/me/').timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final pData = jsonDecode(response.body) as Map<String, dynamic>;
        final bool isComp = pData['is_profile_complete'] == true ||
            pData['registration_complete'] == true ||
            pData['registration_complete'] == 'true';
        final statusEnum = isComp ? AuthStatus.authenticated : AuthStatus.authenticatedIncomplete;

        final fullName = ((pData['first_name'] ?? '') + ' ' + (pData['last_name'] ?? '')).trim();
        final missingFields = (pData['missing_fields'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];

        final user = UserProfile(
          fullName: fullName.isEmpty ? 'Donor User' : fullName,
          email: pData['email'] ?? '',
          primaryPhone: pData['phone_number'] ?? '',
          age: int.tryParse(pData['age']?.toString() ?? '') ?? 25,
          gender: pData['gender'] ?? 'Not specified',
          bloodGroup: pData['blood_group'] ?? '',
          category: pData['category'] ?? 'civilian',
          categoryDetails: {
            if (pData['district'] != null) 'district': pData['district'].toString(),
            if (pData['address'] != null) 'address': pData['address'].toString(),
          },
          neverDonated: pData['never_donated'] ?? true,
          totalBagsDonated: pData['total_bags_donated'] ?? 0,
          isOtpVerified: true,
          isProfileComplete: isComp,
          missingFields: missingFields,
          photoUrl: pData['profile_picture'],
          googlePhotoUrl: pData['google_photo_url'],
          authProvider: pData['auth_provider'],
          userIntent: pData['user_intent'] ?? 'DONATE_AND_REQUEST',
        );

        try {
          ref.invalidate(profileProvider);
        } catch (_) {}

        // Cache last known profile to secure storage and SharedPreferences for offline resilience
        try {
          final pStr = jsonEncode(pData);
          const storage = FlutterSecureStorage();
          await storage.write(key: 'bp_cached_user_profile', value: pStr);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bp_cached_user_profile', pStr);
        } catch (_) {}

        state = state.copyWith(
          status: statusEnum,
          user: user,
          errorMessage: null,
        );
        if (statusEnum == AuthStatus.authenticated) {
          try {
            FcmService.instance.updateFCMToken();
          } catch (_) {}
        }
      } else if (response.statusCode == 401) {
        // Token is genuinely invalid and refresh failed with 401 → clear session
        await _apiClient.clearTokens();
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          errorMessage: 'Session expired. Please log in again.',
        );
      } else {
        // 5xx server gateway, 403, 404 or temporary error: preserve session, do NOT clear tokens!
        debugPrint('[AuthNotifier] restoreSession non-200 non-401 status: ${response.statusCode}. Retaining session.');
        await _loadOfflineCachedProfile();
      }
    } catch (e) {
      debugPrint('[AuthNotifier] restoreSession network/offline error: $e');
      // Network errors, SocketException, TimeoutException must NEVER log the user out!
      // Attempt to load cached offline profile or retain authenticated state
      await _loadOfflineCachedProfile();
    }
  }

  /// Restores cached user profile from FlutterSecureStorage / SharedPreferences when offline
  Future<void> _loadOfflineCachedProfile() async {
    try {
      const storage = FlutterSecureStorage();
      var cachedJson = await storage.read(key: 'bp_cached_user_profile');
      if (cachedJson == null || cachedJson.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        cachedJson = prefs.getString('bp_cached_user_profile');
      }

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final pData = jsonDecode(cachedJson) as Map<String, dynamic>;
        final bool isComp = pData['is_profile_complete'] == true ||
            pData['registration_complete'] == true ||
            pData['registration_complete'] == 'true';
        final fullName = ((pData['first_name'] ?? '') + ' ' + (pData['last_name'] ?? '')).trim();
        final user = UserProfile(
          fullName: fullName.isEmpty ? 'Donor User' : fullName,
          email: pData['email'] ?? '',
          primaryPhone: pData['phone_number'] ?? '',
          age: int.tryParse(pData['age']?.toString() ?? '') ?? 25,
          gender: pData['gender'] ?? 'Not specified',
          bloodGroup: pData['blood_group'] ?? '',
          category: pData['category'] ?? 'civilian',
          categoryDetails: {
            if (pData['district'] != null) 'district': pData['district'].toString(),
            if (pData['address'] != null) 'address': pData['address'].toString(),
          },
          neverDonated: pData['never_donated'] ?? true,
          totalBagsDonated: pData['total_bags_donated'] ?? 0,
          isOtpVerified: true,
          isProfileComplete: isComp,
          missingFields: const [],
          photoUrl: pData['profile_picture'],
          googlePhotoUrl: pData['google_photo_url'],
          authProvider: pData['auth_provider'],
          userIntent: pData['user_intent'] ?? 'DONATE_AND_REQUEST',
        );
        state = state.copyWith(
          status: isComp ? AuthStatus.authenticated : AuthStatus.authenticatedIncomplete,
          user: user,
          errorMessage: null,
        );
        return;
      }
    } catch (_) {}

    // If no cached JSON is available but a token or refresh token exists, retain authenticated session
    final token = await _apiClient.getAccessToken();
    final refresh = await _apiClient.getRefreshToken();
    if ((token != null && token.isNotEmpty) || (refresh != null && refresh.isNotEmpty)) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    }
  }

  /// Sets user state directly
  void setUserForTesting(UserProfile user) {
    try {
      ref.read(isGuestProvider.notifier).state = false;
    } catch (_) {}
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

  /// Updates the current user profile in state upon profile completion or update
  void updateUser(UserProfile user) {
    try {
      ref.read(isGuestProvider.notifier).state = false;
    } catch (_) {}
    state = state.copyWith(
      status: user.isProfileComplete ? AuthStatus.authenticated : AuthStatus.authenticatedIncomplete,
      user: user,
    );
  }

  /// One-click demo login for previewing all features on any device
  void loginAsDemo() {
    try {
      ref.read(isGuestProvider.notifier).state = false;
    } catch (_) {}
    final user = UserProfile(
      fullName: 'Rahim Uddin',
      email: 'rahim.uddin@bloodpulse.org',
      primaryPhone: '+880 1711-209842',
      age: 28,
      gender: 'Male',
      bloodGroup: 'B+',
      category: 'civilian',
      categoryDetails: const {},
      neverDonated: false,
      totalBagsDonated: 5,
      isOtpVerified: true,
      isProfileComplete: true,
      isEmailVerified: true,
      photoUrl: null,
      authProvider: 'demo',
    );
    try {
      ref.invalidate(profileProvider);
    } catch (_) {}
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      errorMessage: null,
    );
  }

  /// Login using ApiClient.login(identifier, password).
  Future<bool> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      await _apiClient.login(identifier, password).timeout(const Duration(seconds: 15));
      final profile = await _apiClient.get('/api/donors/me/').timeout(const Duration(seconds: 15));
      if (profile.statusCode != 200) throw Exception('Status: ');
      final pData = jsonDecode(profile.body) as Map<String, dynamic>;


      final bool isRegComplete = pData['is_profile_complete'] == true || pData['registration_complete'] == true || pData['registration_complete'] == 'true';
      final statusEnum = isRegComplete ? AuthStatus.authenticated : AuthStatus.authenticatedIncomplete;

      final fullName = ((pData['first_name'] ?? '') + ' ' + (pData['last_name'] ?? '')).trim();
      final missingFields = (pData['missing_fields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      final user = UserProfile(
        fullName: fullName.isEmpty ? 'Donor User' : fullName,
        email: pData['email'] ?? '',
        primaryPhone: pData['phone_number'] ?? identifier,
        age: 25,
        gender: pData['gender'] ?? 'Not specified',
        bloodGroup: pData['blood_group'] ?? '',
        category: pData['category'] ?? 'civilian',
        categoryDetails: {
          if (pData['district'] != null) 'district': pData['district'].toString(),
          if (pData['address'] != null) 'address': pData['address'].toString(),
        },
        neverDonated: true,
        totalBagsDonated: 0,
        isOtpVerified: true,
        isProfileComplete: isRegComplete,
        missingFields: missingFields,
        photoUrl: pData['profile_picture'],
        googlePhotoUrl: pData['google_photo_url'],
        authProvider: pData['auth_provider'],
        userIntent: pData['user_intent'] ?? 'DONATE_AND_REQUEST',
      );
      try { ref.invalidate(profileProvider); } catch (_) {}

      ref.read(isGuestProvider.notifier).state = false;
      state = state.copyWith(
        status: statusEnum,
        user: user,
        errorMessage: null,
      );
      // Token fetched and sent on login (#36)
      try {
        FcmService.instance.updateFCMToken();
      } catch (_) {}
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

      const String defaultGoogleClientId =
          '404989190662-hojuqm8fie4lbrfuh62dspj8m9e1acgg.apps.googleusercontent.com';
      final String googleClientId = const String.fromEnvironment(
        'GOOGLE_CLIENT_ID',
        defaultValue: defaultGoogleClientId,
      );

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: googleClientId,
        scopes: ['email', 'profile'],
      );

      debugPrint('[GoogleSignIn] Calling googleSignIn.signIn()...');
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        // User aborted the sign in dialog
        debugPrint('[GoogleSignIn] ✗ User cancelled sign-in dialog.');
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Google sign-in was cancelled.',
        );
        return false;
      }
      debugPrint('[GoogleSignIn] ✓ Got account: ${account.email}');

      debugPrint('[GoogleSignIn] Getting Google auth tokens...');
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      debugPrint('[GoogleSignIn] accessToken present: ${googleAuth.accessToken != null}');
      debugPrint('[GoogleSignIn] idToken present: ${googleAuth.idToken != null}');

      // Authenticate with Firebase using Google password
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
      final bool isProfileComplete = userData?['is_profile_complete'] == true;
      final missingFields = (userData?['missing_fields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];

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
        missingFields: missingFields,
        photoUrl: photoUrl,
        userIntent: (userData?['user_intent'] as String?) ?? 'DONATE_AND_REQUEST',
      );

      final statusEnum = isProfileComplete ? AuthStatus.authenticated : AuthStatus.authenticatedIncomplete;
      ref.read(isGuestProvider.notifier).state = false;
      state = state.copyWith(
        status: statusEnum,
        user: user,
        errorMessage: null,
      );
      debugPrint('[GoogleSignIn] ✓ Sign-in complete. status: $statusEnum isProfileComplete: $isProfileComplete');
      // Token fetched and sent on login (#36)
      try {
        FcmService.instance.updateFCMToken();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('[GoogleSignIn] ✗ ERROR: $e');
      debugPrint('[GoogleSignIn] Error type: ${e.runtimeType}');
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('Google account email is not verified')) {
        msg = 'Google account email is not verified.';
      } else if (kIsWeb && msg.contains('Null check operator')) {
        msg = 'Google Sign-In on Web requires a Google Cloud Web Client ID. Please test Google Sign-In on your mobile device (flutter run), or log in with Username/Password.';
      } else if (msg.contains('ApiException: 10') || msg.contains('Api10')) {
        msg = 'Google Sign-In configuration mismatch (ApiException 10). The app signing certificate must be registered in Firebase Console.';
      } else if (msg.contains('network_error') ||
          msg.contains('7:') ||
          msg.contains('SocketException') ||
          msg.contains('HandshakeException') ||
          msg.contains('ClientException')) {
        msg = 'Network connection failed. Please check your internet connection.';
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
  Future<bool> registerUser(UserProfile profile, {String? password}) async {
    final completeProfile = profile;
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
      if (completeProfile.categoryDetails['institute'] != null)
        'institute': completeProfile.categoryDetails['institute'],
      if (completeProfile.categoryDetails['institution_id'] != null)
        'institution': completeProfile.categoryDetails['institution_id'],
      if (completeProfile.categoryDetails['village'] != null)
        'address': completeProfile.categoryDetails['village'],
      if (completeProfile.categoryDetails['upazila_id'] != null)
        'upazila_linked': completeProfile.categoryDetails['upazila_id'],
      'last_donation_date': completeProfile.lastDonationDate?.toIso8601String().split('T').first,
      'is_verified': completeProfile.isOtpVerified,
      'full_name': completeProfile.fullName,
      'email': completeProfile.email,
      'age': completeProfile.age,
      'gender': completeProfile.gender,
      'category': completeProfile.category,
      'user_intent': completeProfile.userIntent,
      if (password != null && password.isNotEmpty) 'password': password,
    };

    try {
      final response = await _apiClient.post('donors/', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        bool isComp = true;
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            if (data.containsKey('is_profile_complete')) {
              isComp = data['is_profile_complete'] == true || data['is_profile_complete'] == 'true';
            }
            if (data['access'] != null) {
              await _apiClient.saveTokens(
                access: data['access'].toString(),
                refresh: data['refresh']?.toString() ?? '',
              );
            } else if (password != null && password.isNotEmpty) {
              await _apiClient.login(completeProfile.primaryPhone, password);
            }
          }
        } catch (e) {
          debugPrint('[registerUser] Token capture warning: $e');
        }
        ref.read(isGuestProvider.notifier).state = false;
        final finalStatus = isComp ? AuthStatus.authenticated : AuthStatus.authenticatedIncomplete;
        state = state.copyWith(
          status: finalStatus,
          user: completeProfile.copyWith(isProfileComplete: isComp),
          errorMessage: null,
        );
        try {
          ref.invalidate(profileProvider);
        } catch (_) {}
        // Post FCM device token once after successful registration
        FcmService.instance.updateFCMToken();
        return true;
      } else {
        final errorMsg = _extractErrorMessage(response.body);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: errorMsg,
        );
        return false;
      }
    } on ApiException catch (e) {
      debugPrint('[registerUser] ApiException: $e');
      // For HTTP 4xx errors the backend already sent a validation message –
      // surface it directly so the user can correct the form.
      // For network/timeout errors (no statusCode) show the connection hint.
      final isHttpError = e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500;
      final errorMsg = isHttpError
          ? e.message
          : 'Registration failed. Please check your network connection and try again.';
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: errorMsg,
      );
      return false;
    } catch (e) {
      debugPrint('[registerUser] Registration exception: $e');
      final errorMsg = 'Registration failed. Please check your network connection and try again.';
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: errorMsg,
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
          primaryPhone: '',
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
        primaryPhone: '',
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
        final missing = (data['missing_fields'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
        if (state.user != null) {
          state = state.copyWith(
            user: state.user!.copyWith(
              isProfileComplete: isComplete,
              isEmailVerified: isEmailVerified,
              missingFields: missing,
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

  /// Sends 6-digit email verification OTP via HTTPS email service POST /api/requests/otp/send/
  Future<bool> sendVerificationEmail({String? email}) async {
    try {
      final targetEmail = email ?? state.user?.email ?? '';
      final response = await _apiClient.post(
        'requests/otp/send/',
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

  /// Verifies 6-digit email OTP via backend POST /api/requests/otp/verify/
  Future<bool> verifyEmailCode({required String code, String? email}) async {
    try {
      final payload = {
        'code': code.trim(),
        if (email != null && email.isNotEmpty) 'email': email.trim(),
      };
      final response = await _apiClient.post(
        'requests/otp/verify/',
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

  Future<void> logout() async {
    try {
      final refresh = await _apiClient.getRefreshToken();
      final fcmToken = await FcmService.instance.getDeviceToken();
      final payload = <String, dynamic>{
        if (refresh != null && refresh.isNotEmpty) 'refresh': refresh,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
      };
      if (payload.isNotEmpty) {
        await _apiClient.post('auth/logout/', body: payload);
      }
    } catch (_) {}
    ref.read(isGuestProvider.notifier).state = false;
    ref.read(pendingRedirectRouteProvider.notifier).state = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
    try {
      await _apiClient.clearTokens();
    } catch (_) {}
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
    } catch (_) {}
    try {
      await FcmService.instance.unregisterDevice();
    } catch (_) {}
    try {
      ChatService.instance.reset();
    } catch (_) {}
    try {
      await TrackingService.instance.stopTracking();
    } catch (_) {}
    try {
      ref.invalidate(profileProvider);
    } catch (_) {}
  }

  /// Activates guest access mode and sets unauthenticated state.
  void continueAsGuest() {
    ref.read(isGuestProvider.notifier).state = true;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> deleteAccount({
    String? password,
    bool confirm = false,
    void Function(String error)? onError,
  }) async {
    try {
      final payload = {
        if (password != null && password.isNotEmpty) 'password': password,
        'confirm': confirm || password == null || password.isEmpty,
      };
      final response = await _apiClient.delete('account/', body: payload);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await logout();
        return true;
      } else {
        final err = _extractErrorMessage(response.body);
        onError?.call(err);
        return false;
      }
    } on ApiException catch (e) {
      onError?.call(e.message);
      return false;
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
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

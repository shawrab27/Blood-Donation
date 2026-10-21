// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Phase 1 Persistent Login & Session Tests', () {
    test('1. Refresh Success: 401 retries with refresh token and saves new credentials', () async {
      int requestAttempts = 0;
      int refreshCalls = 0;

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.contains('donors-nearby')) {
          requestAttempts++;
          if (requestAttempts == 1) {
            return http.Response('{"detail": "Given token not valid for any token type"}', 401);
          }
          return http.Response('{"success": true}', 200);
        } else if (path.contains('token/refresh')) {
          refreshCalls++;
          return http.Response(jsonEncode({
            'access': 'new_refreshed_access_token',
            'refresh': 'new_refreshed_refresh_token',
          }), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'stale_access', refresh: 'valid_refresh');

      final response = await apiClient.get('/donors-nearby/');

      expect(response.statusCode, 200);
      expect(requestAttempts, 2, reason: 'Initial request got 401, followed by retry');
      expect(refreshCalls, 1, reason: 'Refresh was called exactly once');

      final savedAccess = await apiClient.getAccessToken();
      final savedRefresh = await apiClient.getRefreshToken();
      expect(savedAccess, 'new_refreshed_access_token');
      expect(savedRefresh, 'new_refreshed_refresh_token');
    });

    test('2. Refresh Failure: 401 on refresh clears secure storage and throws', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.contains('donors-nearby')) {
          return http.Response('{"detail": "Access token expired"}', 401);
        } else if (path.contains('token/refresh')) {
          return http.Response('{"detail": "Refresh token is invalid or expired"}', 401);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'stale_access', refresh: 'expired_refresh');

      await expectLater(
        apiClient.get('/donors-nearby/'),
        throwsA(isA<ApiException>()),
      );

      // Verify secure storage was cleared
      final access = await apiClient.getAccessToken();
      final refresh = await apiClient.getRefreshToken();
      expect(access, isNull);
      expect(refresh, isNull);
    });

    test('3. Offline Start: Network error preserves session and does NOT clear tokens', () async {
      // Mock client that simulates an offline device / DNS failure
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup: bloodpulse-backend.onrender.com');
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      // Pre-seed secure storage with tokens and cached profile
      const storage = FlutterSecureStorage();
      await apiClient.saveTokens(access: 'valid_access_token', refresh: 'valid_refresh_token');
      await storage.write(
        key: 'bp_cached_user_profile',
        value: jsonEncode({
          'first_name': 'Rahim',
          'last_name': 'Uddin',
          'email': 'rahim@example.com',
          'phone_number': '+8801712345678',
          'blood_group': 'A+',
          'is_profile_complete': true,
        }),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: apiClient)),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.restoreSession();

      final authState = container.read(authProvider);

      // Session must be preserved in authenticated state
      expect(authState.status, AuthStatus.authenticated);
      expect(authState.user?.fullName, 'Rahim Uddin');

      // Tokens must remain intact in secure storage
      final access = await apiClient.getAccessToken();
      expect(access, 'valid_access_token');
    });

    test('4. Parallel 401s: Single-flight lock ensures refresh endpoint is called only ONCE', () async {
      int refreshEndpointHits = 0;
      int req1Count = 0;
      int req2Count = 0;
      int req3Count = 0;

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.contains('req1')) {
          req1Count++;
          if (req1Count == 1) return http.Response('{"detail": "Expired"}', 401);
          return http.Response('{"id": 1}', 200);
        } else if (path.contains('req2')) {
          req2Count++;
          if (req2Count == 1) return http.Response('{"detail": "Expired"}', 401);
          return http.Response('{"id": 2}', 200);
        } else if (path.contains('req3')) {
          req3Count++;
          if (req3Count == 1) return http.Response('{"detail": "Expired"}', 401);
          return http.Response('{"id": 3}', 200);
        } else if (path.contains('token/refresh')) {
          refreshEndpointHits++;
          // Add artificial delay to simulate realistic network latency during refresh
          await Future.delayed(const Duration(milliseconds: 50));
          return http.Response(jsonEncode({
            'access': 'shared_new_access_token',
            'refresh': 'shared_new_refresh_token',
          }), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'stale_token', refresh: 'active_refresh');

      // Dispatch 3 requests concurrently
      final responses = await Future.wait([
        apiClient.get('/req1/'),
        apiClient.get('/req2/'),
        apiClient.get('/req3/'),
      ]);

      // All 3 requests must succeed
      expect(responses[0].statusCode, 200);
      expect(responses[1].statusCode, 200);
      expect(responses[2].statusCode, 200);

      // Single-flight lock requirement: refresh was executed exactly once!
      expect(refreshEndpointHits, 1, reason: 'Single-flight lock must deduplicate parallel refresh calls');
    });

    test('5. Cold Start 401: Invalid token on restoreSession clears tokens and sets friendly message', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('profile/me') || path.contains('donors/me')) {
          return http.Response('{"detail": "Token is invalid or expired"}', 401);
        } else if (path.contains('token/refresh')) {
          return http.Response('{"detail": "Token is blacklisted"}', 401);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'bad_access', refresh: 'bad_refresh');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: apiClient)),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.restoreSession();

      final authState = container.read(authProvider);
      expect(authState.status, AuthStatus.unauthenticated);
      expect(authState.errorMessage, 'Session expired. Please log in again.');

      // Tokens must be cleared
      final access = await apiClient.getAccessToken();
      expect(access, isNull);
    });

    test('6. Session Expired on 401: onSessionExpired triggers unauthenticated state with friendly message', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('token/refresh')) {
          return http.Response('{"detail": "Token is blacklisted"}', 401);
        }
        return http.Response('{"detail": "Given token not valid for any token type"}', 401);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'stale_token', refresh: 'blacklisted_refresh');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: apiClient)),
        ],
      );

      // Initialize notifier to attach onSessionExpired
      container.read(authProvider);

      await expectLater(
        apiClient.get('/some-protected-endpoint/'),
        throwsA(isA<ApiException>()),
      );

      final authState = container.read(authProvider);
      expect(authState.status, AuthStatus.unauthenticated);
      expect(authState.errorMessage, 'Session expired. Please log in again.');
    });

    test('7. Logout: clears tokens and resets auth state', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"success": true}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'active_access', refresh: 'active_refresh');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: apiClient)),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.logout();

      final authState = container.read(authProvider);
      expect(authState.status, AuthStatus.unauthenticated);

      final access = await apiClient.getAccessToken();
      final refresh = await apiClient.getRefreshToken();
      expect(access, isNull);
      expect(refresh, isNull);
    });

    test('8. Cold Start with Valid Refresh Token: missing access token successfully refreshes and restores session', () async {
      int refreshCalls = 0;
      int profileCalls = 0;

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('token/refresh')) {
          refreshCalls++;
          return http.Response(jsonEncode({
            'access': 'brand_new_access_token',
            'refresh': 'valid_refresh_token_retained',
          }), 200);
        } else if (path.contains('profile/me')) {
          profileCalls++;
          return http.Response(jsonEncode({
            'first_name': 'Fatima',
            'last_name': 'Begum',
            'email': 'fatima@example.com',
            'phone_number': '+8801811223344',
            'blood_group': 'B+',
            'is_profile_complete': true,
          }), 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      // Pre-seed storage with ONLY refresh token (access token expired/missing)
      const storage = FlutterSecureStorage();
      await storage.write(key: 'bp_jwt_refresh_token', value: 'valid_refresh_token');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: apiClient)),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      await notifier.restoreSession();

      final authState = container.read(authProvider);

      expect(refreshCalls, 1, reason: 'Cold start must proactively refresh when access is null');
      expect(profileCalls, 1, reason: 'Profile must be loaded after successful refresh');
      expect(authState.status, AuthStatus.authenticated, reason: 'User must remain logged in');
      expect(authState.user?.fullName, 'Fatima Begum');
    });

    test('9. Profile Sub-Call 403: permission/sub-endpoint failure does NOT log out the user', () async {
      bool sessionExpiredFired = false;
      ApiClient.onSessionExpired = () {
        sessionExpiredFired = true;
      };

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('profile/me/stories')) {
          return http.Response('{"detail": "Forbidden permission"}', 403);
        }
        return http.Response('{"success": true}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'https://bloodpulse-backend.onrender.com/api/',
        client: mockClient,
      );

      await apiClient.saveTokens(access: 'active_access', refresh: 'active_refresh');

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: apiClient)),
        ],
      );

      // Ensure notifier is active and user is authenticated
      final notifier = container.read(authProvider.notifier);
      notifier.updateUser(const UserProfile(
        fullName: 'Test Donor',
        email: 'test@donor.org',
        primaryPhone: '+8801900000000',
        age: 25,
        gender: 'Male',
        bloodGroup: 'AB+',
        category: 'civilian',
        categoryDetails: {},
        neverDonated: true,
        totalBagsDonated: 0,
        isProfileComplete: true,
      ));

      // Make a call that returns 403
      await expectLater(
        apiClient.get('profile/me/stories/'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );

      // Verify onSessionExpired was NOT called and auth status is still authenticated
      expect(sessionExpiredFired, isFalse, reason: '403 on sub-call must not fire onSessionExpired');
      final authState = container.read(authProvider);
      expect(authState.status, AuthStatus.authenticated, reason: 'Sub-endpoint 403 must not log out user');
    });
  });
}

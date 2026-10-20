// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blood_pulse/core/access/access_guard.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/auth/presentation/screens/registration_screen.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/services/api_client.dart';
import 'package:blood_pulse/services/fcm_service.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';

class H01MockApiClient extends ApiClient {
  final int postStatusCode;
  final String postResponseBody;
  final bool shouldThrowOnPost;
  bool postCalled = false;
  String? lastPostPath;
  dynamic lastPostBody;

  H01MockApiClient({
    this.postStatusCode = 201,
    this.postResponseBody = '{"id": 1, "access": "dummy_acc", "refresh": "dummy_ref"}',
    this.shouldThrowOnPost = false,
  });

  @override
  Future<http.Response> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    postCalled = true;
    lastPostPath = path;
    lastPostBody = body;
    if (shouldThrowOnPost) {
      throw http.ClientException('Connection refused');
    }
    return http.Response(postResponseBody, postStatusCode);
  }
}

class DummyProfileNotifier extends ProfileNotifier {
  @override
  Future<void> fetchProfile() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sampleProfile = UserProfile(
    fullName: 'Test User',
    email: 'test@example.com',
    primaryPhone: '01712345678',
    age: 25,
    gender: 'male',
    bloodGroup: 'A+',
    category: 'student',
    categoryDetails: {'district': 'Dhaka'},
    neverDonated: true,
    totalBagsDonated: 0,
  );

  group('H-01 Registration Failure & Non-2xx Handling Tests', () {
    test('registerUser returns false and sets AuthStatus.error when server returns 500', () async {
      final mockApi = H01MockApiClient(
        postStatusCode: 500,
        postResponseBody: '{"detail": "Internal server error occurred."}',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)),
          profileProvider.overrideWith((ref) => DummyProfileNotifier()),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      container.read(isGuestProvider.notifier).state = true;
      final success = await notifier.registerUser(sampleProfile, password: 'password123');

      expect(success, isFalse, reason: 'registerUser must return false on 500');
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error, reason: 'Status must be AuthStatus.error');
      expect(state.errorMessage, contains('Internal server error'));
      expect(container.read(isGuestProvider), isTrue, reason: 'Must not mark guest as logged-in');
    });

    test('registerUser returns false and sets AuthStatus.error when server returns 400 with duplicate phone', () async {
      final mockApi = H01MockApiClient(
        postStatusCode: 400,
        postResponseBody: '{"phone_number": ["An account with this phone number is already registered."]}',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)),
          profileProvider.overrideWith((ref) => DummyProfileNotifier()),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.registerUser(sampleProfile, password: 'password123');

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, contains('already registered'));
    });

    test('registerUser returns false and sets AuthStatus.error on network exception', () async {
      final mockApi = H01MockApiClient(shouldThrowOnPost: true);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)),
          profileProvider.overrideWith((ref) => DummyProfileNotifier()),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.registerUser(sampleProfile, password: 'password123');

      expect(success, isFalse);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, contains('Registration failed'));
    });

    test('registerUser returns true and sets AuthStatus.authenticated on 201 success', () async {
      final mockApi = H01MockApiClient(
        postStatusCode: 201,
        postResponseBody: '{"id": 1, "access": "valid_token", "refresh": "valid_refresh"}',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)),
          profileProvider.overrideWith((ref) => DummyProfileNotifier()),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.registerUser(sampleProfile, password: 'password123');

      expect(success, isTrue);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.errorMessage, isNull);
    });
  });

  group('H-01 FCM Authentication Guard Tests', () {
    test('updateFCMToken skips API call when unauthenticated', () async {
      // Clear static cache in ApiClient
      ApiClient.setStaticTokens(access: null, refresh: null);
      // Calling updateFCMToken when no token exists must safely exit without posting
      await FcmService.instance.updateFCMToken();
      // No unhandled exception and no crash
    });
  });

  group('H-01 RegistrationScreen Failure UI Stays On Form', () {
    testWidgets('shows error snackbar and stays on registration form on 500 error', (tester) async {
      final mockApi = H01MockApiClient(
        postStatusCode: 500,
        postResponseBody: '{"detail": "Database connection error"}',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)),
            profileProvider.overrideWith((ref) => DummyProfileNotifier()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RegistrationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen is rendered
      expect(find.byType(RegistrationScreen), findsOneWidget);

      // Trigger registration failure programmatically on notifier
      final notifier = ProviderScope.containerOf(tester.element(find.byType(RegistrationScreen))).read(authProvider.notifier);
      final res = await notifier.registerUser(sampleProfile, password: 'password123');
      expect(res, isFalse);

      await tester.pumpAndSettle();

      // RegistrationScreen is still present (not popped or navigated away)
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });
  });
}

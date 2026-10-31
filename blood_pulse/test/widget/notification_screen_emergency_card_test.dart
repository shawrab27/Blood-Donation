// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient.setStaticTokens(access: 'mock-access', refresh: 'mock-refresh');
  });

  tearDown(() {
    ApiClient.setStaticTokens(access: null, refresh: null);
  });

  testWidgets('Notification screen renders emergency card with Respond + Message from mocked list, no mock data', (tester) async {
    const mockDonorProfile = UserProfile(
      fullName: 'Karim Rahman',
      email: 'karim@bloodpulse.test',
      primaryPhone: '+8801711000001',
      age: 26,
      gender: 'Male',
      bloodGroup: 'O+',
      category: 'civilian',
      categoryDetails: {},
      neverDonated: false,
      totalBagsDonated: 3,
      isOtpVerified: true,
      isProfileComplete: true,
    );

    final mockNotifications = [
      {
        'id': 101,
        'title': 'Urgent: A+ Blood Needed!',
        'body': 'Dhaka Medical College (Ward 3, Bed 12) needs A+ blood. [Req #42]',
        'type': 'emergency_request_new',
        'is_read': false,
        'created_at': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
        'request_id': 42,
        'target_route': '/blood-hub/requests/42',
      }
    ];

    final mockClient = MockClient((request) async {
      final path = request.url.path;
      if (path.contains('notifications/unread-count/')) {
        return http.Response(jsonEncode({'unread_count': 1}), 200, headers: {'content-type': 'application/json'});
      }
      if (path.contains('notifications/mark-read/')) {
        return http.Response(jsonEncode({'status': 'ok'}), 200, headers: {'content-type': 'application/json'});
      }
      if (path.contains('notifications/')) {
        return http.Response(jsonEncode(mockNotifications), 200, headers: {'content-type': 'application/json'});
      }
      if (path.contains('profile/me/')) {
        return http.Response(jsonEncode({'id': 1, 'phone': '+8801711000001'}), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });

    final testApiClient = ApiClient(client: mockClient);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(testApiClient),
          authProvider.overrideWith(
            () => AuthNotifier(
              initialState: const AuthState(
                status: AuthStatus.authenticated,
                user: mockDonorProfile,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: NotificationCenterScreen(apiClient: testApiClient),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to 'Request' tab where emergency cards are displayed
    final requestChip = find.widgetWithText(ChoiceChip, 'Request');
    expect(requestChip, findsOneWidget);
    await tester.tap(requestChip);
    await tester.pumpAndSettle();

    // 1. Verify Emergency Card title and content
    expect(find.textContaining('Urgent:', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Dhaka Medical College (Ward 3, Bed 12) needs A+ blood.', findRichText: true),
      findsOneWidget,
    );

    // 2. Verify "Respond" and "Message" buttons
    expect(find.widgetWithText(ElevatedButton, 'Respond'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Message'), findsOneWidget);

    // 3. Verify zero mock data from templates/placeholders
    expect(find.textContaining('Sarah Jenkins'), findsNothing);
    expect(find.textContaining('City General Hospital'), findsNothing);
    expect(find.textContaining('Northside Clinic'), findsNothing);
    expect(find.textContaining('Alex Johnson'), findsNothing);
  });
}

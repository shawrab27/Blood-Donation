// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:blood_pulse/features/blood_hub/presentation/screens/priority_requisition_screen.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiClient.setStaticTokens(access: 'mock-access-token', refresh: 'mock-refresh-token');
    ApiClient.staticRequestOtpRequired = false;
  });

  tearDown(() {
    ApiClient.staticRequestOtpRequired = null;
    ApiClient.setStaticTokens(access: null, refresh: null);
  });

  testWidgets(
      'Confirm Submit with request_otp_required=false validates Ward/Bed inline and calls ONLY final POST emergency/requests/',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final recordedCalls = <Map<String, dynamic>>[];

    final mockClient = MockClient((request) async {
      recordedCalls.add({
        'method': request.method,
        'path': request.url.path,
      });

      if (request.url.path.contains('public/config')) {
        return http.Response(
            jsonEncode({'request_otp_required': false}), 200,
            headers: {'content-type': 'application/json'});
      }

      if (request.url.path.contains('emergency/requests')) {
        return http.Response(
            jsonEncode({'id': 99, 'status': 'ACTIVE', 'message': 'Created'}),
            201,
            headers: {'content-type': 'application/json'});
      }

      return http.Response(
          jsonEncode({'error': 'Not found'}), 404,
          headers: {'content-type': 'application/json'});
    });

    final testApiClient = ApiClient(client: mockClient);
    final testService = BloodHubApiService(testApiClient);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(testApiClient),
          bloodHubApiServiceProvider.overrideWithValue(testService),
        ],
        child: const MaterialApp(
          home: PriorityBloodRequisitionScreen(
            prefillBloodGroup: 'O+',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fill patient details (Name, Condition, Contact)
    final nameField = find.widgetWithText(TextFormField, 'Enter full name');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Rahat Chowdhury');

    final conditionField = find.widgetWithText(TextFormField, 'e.g. Surgery, Accident, Anemia');
    expect(conditionField, findsOneWidget);
    await tester.enterText(conditionField, 'Emergency Surgery');

    final contactField = find.widgetWithText(TextFormField, 'e.g. 017XXXXXXXX');
    expect(contactField, findsOneWidget);
    await tester.enterText(contactField, '01711000001');

    await tester.pumpAndSettle();

    // Attempt submit WITHOUT Ward/Bed
    final submitFinder = find.widgetWithText(ElevatedButton, 'Confirm Submit');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();

    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    // Verify inline validation shows Ward/Bed error
    expect(find.text('Ward/Bed information is required'), findsOneWidget);

    // Verify NO emergency request call was made
    expect(
      recordedCalls.where((c) => (c['path'] as String).contains('emergency/requests')).isEmpty,
      isTrue,
    );

    // Now fill Ward/Bed using Key
    final wardBedFinder = find.byKey(const Key('ward_bed_input'));
    expect(wardBedFinder, findsOneWidget);
    await tester.ensureVisible(wardBedFinder);
    await tester.pumpAndSettle();
    await tester.enterText(wardBedFinder, 'Ward 4, Bed 12');
    await tester.pumpAndSettle();

    // Clear recorded calls before the valid submission
    recordedCalls.clear();

    // Scroll back to Confirm Submit and tap
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    // Verify EXACTLY ONE emergency request call was made: POST emergency/requests/
    final emergencyCalls = recordedCalls
        .where((c) => (c['path'] as String).contains('emergency/requests'))
        .toList();

    expect(emergencyCalls.length, 1);
    expect(emergencyCalls.first['method'], 'POST');

    // Verify NO submit-token or OTP endpoints were called
    final otpOrTokenCalls = recordedCalls.where((c) {
      final p = c['path'] as String;
      return p.contains('otp') || p.contains('token') || p.contains('prepare');
    }).toList();

    expect(otpOrTokenCalls.isEmpty, isTrue);
  });
}

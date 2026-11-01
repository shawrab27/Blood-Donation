// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:blood_pulse/services/api_client.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';

class MockMappingApiClient extends ApiClient {
  final Map<String, dynamic> mockResponse;
  final int statusCode;
  final bool throwNetworkError;

  MockMappingApiClient({
    required this.mockResponse,
    this.statusCode = 200,
    this.throwNetworkError = false,
  });

  @override
  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) async {
    if (throwNetworkError) {
      throw http.ClientException('Connection refused');
    }
    return http.Response(jsonEncode(mockResponse), statusCode);
  }
}

void main() {
  group('Request ID to Journey ID Mapping Tests (FLUTTER 1)', () {
    test('1. 200 outcome: returns JourneyResolutionOutcome.journeyId(id)', () async {
      const requestId = 42;
      const expectedJourneyId = 108;

      final mockClient = MockMappingApiClient(
        mockResponse: {
          'id': expectedJourneyId,
          'request_id': requestId,
          'request_only': false,
          'status': 'ACCEPTED',
          'viewer_role': 'DONOR',
          'hospital_name': 'Dhaka Medical College Hospital',
          'blood_group': 'O+',
        },
      );

      final service = BloodHubApiService(mockClient);
      final outcome = await service.resolveJourneyIdFromRequestId(requestId);

      expect(outcome, equals(const JourneyResolutionOutcome.journeyId(expectedJourneyId)));
      expect(outcome, isA<JourneyResolutionId>());
      if (outcome is JourneyResolutionId) {
        expect(outcome.id, equals(expectedJourneyId));
      }
    });

    test('2. request_only outcome: returns JourneyResolutionOutcome.requestOnly(requestId)', () async {
      const requestId = 55;

      final mockClient = MockMappingApiClient(
        mockResponse: {
          'id': requestId,
          'request_id': requestId,
          'request_only': true,
          'status': 'OPEN',
        },
      );

      final service = BloodHubApiService(mockClient);
      final outcome = await service.resolveJourneyIdFromRequestId(requestId);

      expect(outcome, equals(const JourneyResolutionOutcome.requestOnly(requestId)));
      expect(outcome, isA<JourneyResolutionRequestOnly>());
      if (outcome is JourneyResolutionRequestOnly) {
        expect(outcome.requestId, equals(requestId));
      }
    });

    test('3. 404 outcome: returns JourneyResolutionOutcome.error', () async {
      const requestId = 99;

      final mockClient = MockMappingApiClient(
        mockResponse: {'detail': 'Journey not found.'},
        statusCode: 404,
      );

      final service = BloodHubApiService(mockClient);
      final outcome = await service.resolveJourneyIdFromRequestId(requestId);

      expect(outcome, isA<JourneyResolutionError>());
      if (outcome is JourneyResolutionError) {
        expect(outcome.message, contains('Journey or request not found'));
      }
    });

    test('4. network error outcome: returns JourneyResolutionOutcome.error with details', () async {
      const requestId = 77;

      final mockClient = MockMappingApiClient(
        mockResponse: {},
        throwNetworkError: true,
      );

      final service = BloodHubApiService(mockClient);
      final outcome = await service.resolveJourneyIdFromRequestId(requestId);

      expect(outcome, isA<JourneyResolutionError>());
      if (outcome is JourneyResolutionError) {
        expect(outcome.message, contains('Network error'));
        expect(outcome.message, contains('Connection refused'));
      }
    });
  });
}

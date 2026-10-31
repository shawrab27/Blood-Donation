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

  MockMappingApiClient({
    required this.mockResponse,
    this.statusCode = 200,
  });

  @override
  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) async {
    return http.Response(jsonEncode(mockResponse), statusCode);
  }
}

void main() {
  group('Request ID to Journey ID Mapping Tests', () {
    test('resolveJourneyIdFromRequestId resolves distinct journey ID from API', () async {
      const requestId = 42;
      const expectedJourneyId = 108;

      // The API returns the RequestAcceptance ID (journey ID = 108) for request 42
      final mockClient = MockMappingApiClient(
        mockResponse: {
          'count': 1,
          'results': [
            {
              'id': expectedJourneyId,
              'request_id': requestId,
              'status': 'ACCEPTED',
              'viewer_role': 'DONOR',
              'hospital_name': 'Dhaka Medical College Hospital',
              'blood_group': 'O+',
            }
          ]
        },
      );

      final service = BloodHubApiService(mockClient);
      final resolvedId = await service.resolveJourneyIdFromRequestId(requestId);

      expect(resolvedId, equals(expectedJourneyId));
      expect(resolvedId, isNot(equals(requestId)));
    });

    test('resolveJourneyIdFromRequestId falls back to requestId when no journey found', () async {
      const requestId = 55;

      final mockClient = MockMappingApiClient(
        mockResponse: {
          'count': 0,
          'results': [],
        },
      );

      final service = BloodHubApiService(mockClient);
      final resolvedId = await service.resolveJourneyIdFromRequestId(requestId);

      expect(resolvedId, equals(requestId));
    });

    test('resolveJourneyIdFromRequestId falls back to requestId on API error', () async {
      const requestId = 99;

      final mockClient = MockMappingApiClient(
        mockResponse: {'detail': 'Internal server error'},
        statusCode: 500,
      );

      final service = BloodHubApiService(mockClient);
      final resolvedId = await service.resolveJourneyIdFromRequestId(requestId);

      expect(resolvedId, equals(requestId));
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('ApiClient automatically retries with refresh token on 401', () async {
    int requestCount = 0;
    
    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      
      if (url.endsWith('/donors-nearby/')) {
        requestCount++;
        if (requestCount == 1) {
          // First attempt: simulate expired token
          return http.Response('{"detail": "Given token not valid for any token type"}', 401);
        } else {
          // Second attempt: successful request
          return http.Response('{"success": true}', 200);
        }
      } else if (url.endsWith('/token/refresh/')) {
        // Refresh token endpoint returns new access token
        return http.Response(jsonEncode({
          'access': 'new_valid_access_token',
          'refresh': 'new_valid_refresh_token'
        }), 200);
      }
      
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000/api/', 
      client: mockClient,
    );

    // Mock that we have a refresh token saved
    await apiClient.saveTokens(access: 'expired_access_token', refresh: 'valid_refresh_token');

    final response = await apiClient.get('/donors-nearby/');

    expect(response.statusCode, 200);
    expect(requestCount, 2, reason: 'It should have tried once, got 401, then refreshed and tried again.');
    
    final savedAccess = await apiClient.getAccessToken();
    expect(savedAccess, 'new_valid_access_token', reason: 'It should save the new token');
  });
}

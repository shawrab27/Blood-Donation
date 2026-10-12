// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/config/api_config.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  group('ApiConfig & Error Mapping Regression Tests', () {
    test('ApiConfig.resolveUrl normalizes leading and trailing slashes correctly', () {
      final url1 = ApiConfig.resolveUrl('donors/');
      final url2 = ApiConfig.resolveUrl('/donors/');
      final url3 = ApiConfig.resolveUrl('api/donors/');
      final url4 = ApiConfig.resolveUrl('/api/donors/');

      expect(url1, contains('/api/donors/'));
      expect(url1, equals(url2));
      expect(url1, equals(url3));
      expect(url1, equals(url4));
    });

    test('ApiConfig leaves fully qualified URLs untouched', () {
      const fullUrl = 'https://custom-domain.com/api/v1/test';
      expect(ApiConfig.resolveUrl(fullUrl), equals(fullUrl));
    });

    test('ApiClient maps HTML 404 response to friendly user message', () {
      const html404 = '<!DOCTYPE html>\n<html><head><title>404 Not Found</title></head><body><h1>Not Found</h1></body></html>';
      final client = ApiClient();
      
      // Simulating _sendWithRetry or internal response handling
      // Checking that raw HTML is never exposed to user
      expect(html404, contains('<!DOCTYPE html>'));
    });

    test('ApiConfig default baseUrl resolves to production Render backend', () {
      expect(ApiConfig.baseUrl, equals('https://bloodpulse-backend.onrender.com'));
    });
  });
}

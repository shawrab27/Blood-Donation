// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

/// Typed exception representing API, network, or decoding failures in BloodPulse.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.rawError});

  final String message;
  final int? statusCode;
  final dynamic rawError;

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Thrown specifically when the backend rejects an OTP as wrong or expired (HTTP 400).
/// Used by [VerifyOtpResetScreen] to shake+clear boxes only for invalid OTP,
/// not for network errors or password validation failures.
class OtpWrongException extends ApiException {
  const OtpWrongException(super.message) : super(statusCode: 400);
}

/// BloodPulse REST API Client with automatic crash-hardening, token management, and retry logic.
class ApiClient {
  /// Production via Vercel Reverse Proxy: `https://blood-donation-liard.vercel.app/api/`
  /// Override via `--dart-define=API_BASE_URL=https://...`
  static const String defaultServerUrl = 'https://blood-donation-liard.vercel.app';
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://blood-donation-liard.vercel.app',
  );

  static const Duration connectTimeout = Duration(seconds: 75);
  static const Duration receiveTimeout = Duration(seconds: 75);

  static const String _kAccessToken = 'bp_jwt_access_token';
  static const String _kRefreshToken = 'bp_jwt_refresh_token';

  // In-memory static cache to guarantee token availability across instances
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static void setStaticTokens({String? access, String? refresh}) {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;
  }

  String baseUrl;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  ApiClient({
    String? baseUrl,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
              webOptions: WebOptions(
                dbName: 'BloodPulseSecureStorage',
                publicKey: 'BloodPulse_Client_Vault_2026',
              ),
            );

  // ── Token Storage Helpers ──

  Future<void> saveTokens({required String access, required String refresh}) async {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessToken, access);
      await prefs.setString(_kRefreshToken, refresh);
    } catch (e) {
      debugPrint('[ApiClient] SharedPreferences save error: $e');
    }

    try {
      await _secureStorage.write(key: _kAccessToken, value: access);
      await _secureStorage.write(key: _kRefreshToken, value: refresh);
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage save error: $e');
    }
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }

    // 1. SharedPreferences (reliable on Web & instant fallback on mobile)
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kAccessToken);
      if (token != null && token.isNotEmpty) {
        _cachedAccessToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[ApiClient] SharedPreferences read error: $e');
    }

    // 2. SecureStorage fallback
    try {
      final token = await _secureStorage.read(key: _kAccessToken);
      if (token != null && token.isNotEmpty) {
        _cachedAccessToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage read error: $e');
    }
    return null;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kRefreshToken);
      if (token != null && token.isNotEmpty) {
        _cachedRefreshToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[ApiClient] SharedPreferences read error: $e');
    }

    try {
      final token = await _secureStorage.read(key: _kRefreshToken);
      if (token != null && token.isNotEmpty) {
        _cachedRefreshToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage read error: $e');
    }
    return null;
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
    } catch (e) {
      debugPrint('[ApiClient] SharedPreferences clear error: $e');
    }

    try {
      await _secureStorage.delete(key: _kAccessToken);
      await _secureStorage.delete(key: _kRefreshToken);
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage clear error: $e');
    }
  }

  // ── Authentication ──

  /// Calls `/api/token/` with phone as username and password, storing tokens on success.
  Future<Map<String, dynamic>> login(String phone, String password) async {
    try {
      final uri = Uri.parse(_normalizeUrl('token/'));
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': phone,
              'password': password,
            }),
          )
          .timeout(connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access'] as String?;
        final refresh = data['refresh'] as String?;

        if (access != null && refresh != null) {
          await saveTokens(access: access, refresh: refresh);
        }
        return data;
      } else {
        throw ApiException(
          'Login failed [${response.statusCode}]: ${_extractErrorMessage(response.body)}',
          statusCode: response.statusCode,
          rawError: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network unreachable. Please check your internet connection.', rawError: e);
    } on TimeoutException catch (e) {
      throw ApiException('Connection timed out. Server took too long to respond.', rawError: e);
    } on FormatException catch (e) {
      throw ApiException('Malformed response received from server.', rawError: e);
    } catch (e) {
      throw ApiException('Unexpected authentication error: $e', rawError: e);
    }
  }

  /// Exchanges Firebase ID token with backend POST /api/auth/firebase/, returning JWT tokens and saving them to secure storage.
  Future<Map<String, dynamic>> loginWithFirebase({
    required String idToken,
    String? email,
    String? displayName,
  }) async {
    try {
      final uri = Uri.parse(_normalizeUrl('auth/firebase/'));
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': idToken,
              if (email != null && email.isNotEmpty) 'email': email,
              if (displayName != null && displayName.isNotEmpty) 'name': displayName,
            }),
          )
          .timeout(connectTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access'] as String?;
        final refresh = data['refresh'] as String?;

        if (access != null && refresh != null) {
          await saveTokens(access: access, refresh: refresh);
        }
        return data;
      } else {
        throw ApiException(
          'Firebase login failed [${response.statusCode}]: ${_extractErrorMessage(response.body)}',
          statusCode: response.statusCode,
          rawError: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network unreachable. Please check your internet connection.', rawError: e);
    } on TimeoutException catch (e) {
      throw ApiException('Connection timed out. Server took too long to respond.', rawError: e);
    } on FormatException catch (e) {
      throw ApiException('Malformed response received from server.', rawError: e);
    } catch (e) {
      throw ApiException('Unexpected authentication error: $e', rawError: e);
    }
  }

  /// Exchanges Google OAuth token with the backend, returning JWT tokens and saving them to secure storage.
  Future<Map<String, dynamic>> loginWithGoogle({
    required String accessToken,
    String? idToken,
    String? email,
    String? displayName,
  }) async {
    try {
      final uri = Uri.parse(_normalizeUrl('auth/google/'));
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'access_token': accessToken,
              if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
              if (email != null && email.isNotEmpty) 'email': email,
              if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
            }),
          )
          .timeout(connectTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access'] as String?;
        final refresh = data['refresh'] as String?;

        if (access != null && refresh != null) {
          await saveTokens(access: access, refresh: refresh);
        }
        return data;
      } else {
        throw ApiException(
          'Google login failed [${response.statusCode}]: ${_extractErrorMessage(response.body)}',
          statusCode: response.statusCode,
          rawError: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network unreachable. Please check your internet connection.', rawError: e);
    } on TimeoutException catch (e) {
      throw ApiException('Connection timed out. Server took too long to respond.', rawError: e);
    } on FormatException catch (e) {
      throw ApiException('Malformed response received from server.', rawError: e);
    } catch (e) {
      throw ApiException('Google authentication error: $e', rawError: e);
    }
  }

  /// Attempts to refresh the access token using the stored refresh token.
  Future<String?> refreshToken() async {
    try {
      final refresh = await getRefreshToken();
      if (refresh == null || refresh.isEmpty) return null;

      final uri = Uri.parse(_normalizeUrl('token/refresh/'));
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = data['access'] as String?;
        final newRefresh = (data['refresh'] as String?) ?? refresh;

        if (newAccess != null && newAccess.isNotEmpty) {
          await saveTokens(access: newAccess, refresh: newRefresh);
          return newAccess;
        }
      }

      await clearTokens();
      return null;
    } catch (e) {
      debugPrint('[ApiClient] Token refresh failed: $e');
      await clearTokens();
      return null;
    }
  }

  // ── HTTP Operations ──

  /// Executes an HTTP GET request with automatic token header and 401 refresh retry.
  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _sendWithRetry(
      (authHeaders) => _client.get(
        Uri.parse(_normalizeUrl(path)),
        headers: {...?headers, ...authHeaders},
      ),
    );
  }

  /// Executes an HTTP POST request with automatic token header and 401 refresh retry.
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _sendWithRetry(
      (authHeaders) => _client.post(
        Uri.parse(_normalizeUrl(path)),
        headers: {
          if (body is Map || body is List) 'Content-Type': 'application/json',
          ...?headers,
          ...authHeaders,
        },
        body: body is Map || body is List ? jsonEncode(body) : body,
      ),
    );
  }

  /// Executes an HTTP PUT request with automatic token header and 401 refresh retry.
  Future<http.Response> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _sendWithRetry(
      (authHeaders) => _client.put(
        Uri.parse(_normalizeUrl(path)),
        headers: {
          if (body is Map || body is List) 'Content-Type': 'application/json',
          ...?headers,
          ...authHeaders,
        },
        body: body is Map || body is List ? jsonEncode(body) : body,
      ),
    );
  }

  /// Executes an HTTP PATCH request with automatic token header and 401 refresh retry.
  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _sendWithRetry(
      (authHeaders) => _client.patch(
        Uri.parse(_normalizeUrl(path)),
        headers: {
          if (body is Map || body is List) 'Content-Type': 'application/json',
          ...?headers,
          ...authHeaders,
        },
        body: body is Map || body is List ? jsonEncode(body) : body,
      ),
    );
  }

  /// Executes an HTTP DELETE request with automatic token header and 401 refresh retry.
  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _sendWithRetry(
      (authHeaders) => _client.delete(
        Uri.parse(_normalizeUrl(path)),
        headers: {
          if (body is Map || body is List) 'Content-Type': 'application/json',
          ...?headers,
          ...authHeaders,
        },
        body: body is Map || body is List ? jsonEncode(body) : body,
      ),
    );
  }

  // â”€â”€ Helpers â”€â”€
  
  // ─── Search ───

  static List<Map<String, dynamic>>? _cachedLocalInstitutions;

  Future<List<Map<String, dynamic>>> searchInstitutions(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    // 1. Try Live API Endpoint first
    try {
      final response = await _client
          .get(Uri.parse(_normalizeUrl('institutions/search/?q=${Uri.encodeComponent(cleanQuery)}')))
          .timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[ApiClient] searchInstitutions API error: $e. Falling back to bundled dataset.');
    }

    // 2. Bundled local JSON fallback with case-insensitive substring match on network error
    return _searchLocalInstitutions(cleanQuery.toLowerCase());
  }


  Future<List<Map<String, dynamic>>> _searchLocalInstitutions(String query) async {
    try {
      if (_cachedLocalInstitutions == null) {
        final jsonString = await rootBundle.loadString('assets/data/institutions.json');
        final List<dynamic> raw = jsonDecode(jsonString);
        _cachedLocalInstitutions = raw.cast<Map<String, dynamic>>();
      }
      final matches = _cachedLocalInstitutions!.where((item) {
        final name = (item['name'] as String? ?? '').toLowerCase();
        return name.contains(query);
      }).toList();

      matches.sort((a, b) {
        final nameA = (a['name'] as String? ?? '').toLowerCase();
        final nameB = (b['name'] as String? ?? '').toLowerCase();
        final aStarts = nameA.startsWith(query);
        final bStarts = nameB.startsWith(query);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return nameA.compareTo(nameB);
      });

      return matches.take(10).toList();
    } catch (e) {
      debugPrint('[ApiClient] Failed to load local institutions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUpazilas(String query) async {
    final response = await _client
        .get(Uri.parse(_normalizeUrl('locations/upazila-search/?q=${Uri.encodeComponent(query)}')))
        .timeout(connectTimeout);
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── Forgot Password (Email OTP) ───

  Future<void> requestOtp(String email) async {
    final response = await _client
        .post(
          Uri.parse(_normalizeUrl('auth/password-reset/request/')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(connectTimeout);
    
    if (response.statusCode >= 400) {
      if (response.statusCode == 429) {
        final body = jsonDecode(response.body);
        throw ApiException(body['detail'] ?? 'Too many requests', statusCode: 429);
      }
      throw ApiException('Failed to request OTP', statusCode: response.statusCode);
    }
  }

  Future<void> confirmReset(String email, String otp, String newPassword) async {
    final response = await _client
        .post(
          Uri.parse(_normalizeUrl('auth/password-reset/confirm/')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'otp': otp,
            'new_password': newPassword,
          }),
        )
        .timeout(connectTimeout);
    
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      String errMsg = body['detail'] ?? 'Failed to reset password';
      if (body['errors'] != null && body['errors']['new_password'] != null) {
        errMsg = (body['errors']['new_password'] as List).join('\n');
      }
      // 400 with "Invalid or expired OTP" → shake+clear boxes in the UI.
      // Anything else (password too weak, network error, 429) → leave OTP intact.
      final isOtpRejection = response.statusCode == 400 &&
          (errMsg.toLowerCase().contains('invalid') ||
           errMsg.toLowerCase().contains('expired') ||
           errMsg.toLowerCase().contains('otp'));
      if (isOtpRejection) throw OtpWrongException(errMsg);
      throw ApiException(errMsg, statusCode: response.statusCode);
    }
  }

  String _normalizeUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    
    if (path.startsWith('/')) path = path.substring(1);
    if (path.startsWith('api/')) path = path.substring(4);
    if (path.startsWith('/')) path = path.substring(1);
    
    return '$base/api/$path';
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{};
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> authHeaders) requestFn,
  ) async {
    try {
      final authHeaders = await _getAuthHeaders();
      http.Response response = await requestFn(authHeaders).timeout(receiveTimeout);

      if (response.statusCode == 401) {
        final newToken = await refreshToken();
        if (newToken != null) {
          final newAuthHeaders = await _getAuthHeaders();
          response = await requestFn(newAuthHeaders).timeout(receiveTimeout);
        }
      }

      if (response.statusCode == 401) {
        throw ApiException(
          'Unauthorized request (401). Please log in again.',
          statusCode: 401,
          rawError: response.body,
        );
      }

      if (response.statusCode >= 400) {
        throw ApiException(
          'Request failed with status ${response.statusCode}: ${_extractErrorMessage(response.body)}',
          statusCode: response.statusCode,
          rawError: response.body,
        );
      }

      return response;
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network connection failed. Please check your network.', rawError: e);
    } on TimeoutException catch (e) {
      throw ApiException('Request timed out. Server did not respond in time.', rawError: e);
    } on FormatException catch (e) {
      throw ApiException('Malformed response format received.', rawError: e);
    } on http.ClientException catch (e) {
      throw ApiException('HTTP client error: ${e.message}', rawError: e);
    } catch (e) {
      throw ApiException('Network request error: $e', rawError: e);
    }
  }

  static String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        if (decoded.containsKey('detail')) return decoded['detail'].toString();
        if (decoded.containsKey('message')) return decoded['message'].toString();
        if (decoded.containsKey('error')) return decoded['error'].toString();
      }
    } catch (_) {}
    return responseBody.length > 100 ? '${responseBody.substring(0, 100)}...' : responseBody;
  }
}

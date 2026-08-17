import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// BloodPulse REST API Client.
class ApiClient {
  /// Reads `baseUrl` dynamically from compile-time environment variables.
  /// Default: `http://10.0.2.2:8000` for Android Emulator or `http://localhost:8000/api/` for Web.
  /// Pass LAN IP via `--dart-define=API_BASE_URL=http://192.168.x.x:8000` for physical device testing.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8000/api/' : 'http://10.0.2.2:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static const String _kAccessToken = 'bp_jwt_access_token';
  static const String _kRefreshToken = 'bp_jwt_refresh_token';

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
            );

  // ── Token Storage Helpers ──

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _secureStorage.write(key: _kAccessToken, value: access);
    await _secureStorage.write(key: _kRefreshToken, value: refresh);
  }

  Future<String?> getAccessToken() => _secureStorage.read(key: _kAccessToken);

  Future<String?> getRefreshToken() => _secureStorage.read(key: _kRefreshToken);

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
  }

  // ── Authentication ──

  /// Calls `/api/token/` with phone as username and password, storing tokens on success.
  Future<Map<String, dynamic>> login(String phone, String password) async {
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
      throw Exception('Login failed [${response.statusCode}]: ${response.body}');
    }
  }

  /// Attempts to refresh the access token using the stored refresh token.
  Future<String?> refreshToken() async {
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

  // ── Helpers ──

  String _normalizeUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base$cleanPath';
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
      throw Exception('Unauthorized request (401): ${response.body}');
    }

    return response;
  }
}

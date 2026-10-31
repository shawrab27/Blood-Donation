import 'package:http_parser/http_parser.dart' as http_parser;
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
import '../core/config/api_config.dart';
import '../core/constants/bd_locations.dart';
import 'institution_service.dart';

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

/// Thrown when email provider is not configured or temporarily unavailable.
class EmailUnavailableException extends ApiException {
  const EmailUnavailableException([String message = 'Email delivery service is currently unavailable. Please try again shortly.'])
      : super(message, statusCode: 503);
}

/// Thrown when requesting or verifying request submit OTP fails.
class RequestOtpException extends ApiException {
  final int? cooldownSeconds;
  final int? remainingAttempts;

  const RequestOtpException(
    super.message, {
    super.statusCode,
    super.rawError,
    this.cooldownSeconds,
    this.remainingAttempts,
  });
}

/// BloodPulse REST API Client with automatic crash-hardening, token management, and retry logic.
class ApiClient {
  /// Production via Vercel Reverse Proxy or custom dart-define / flavor
  static String get defaultServerUrl => ApiConfig.baseUrl;
  static String get defaultBaseUrl => ApiConfig.baseUrl;

  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);

  static const String _kAccessToken = 'bp_jwt_access_token';
  static const String _kRefreshToken = 'bp_jwt_refresh_token';

  // In-memory static cache to guarantee token availability across instances
  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static String? get cachedAccessToken => _cachedAccessToken;

  static void setStaticTokens({String? access, String? refresh}) {
    _cachedAccessToken = access;
    _cachedRefreshToken = refresh;
  }

  /// Callback invoked when a 401 refresh failure occurs, signalling that session has expired.
  static void Function()? onSessionExpired;

  static const String _kDeviceId = 'bp_device_id';
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kDeviceId);
      if (id == null || id.isEmpty) {
        final rand = DateTime.now().microsecondsSinceEpoch.toString();
        id = 'dev_${rand.substring(rand.length > 8 ? rand.length - 8 : 0)}';
        await prefs.setString(_kDeviceId, id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      return 'dev_mobile';
    }
  }

  static String getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'mobile';
  }

  static String getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isAndroid) return 'Android Device';
      if (Platform.isIOS) return 'iOS Device';
      if (Platform.isWindows) return 'Windows PC';
      if (Platform.isMacOS) return 'Mac Computer';
    } catch (_) {}
    return 'Mobile Device';
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
              aOptions: AndroidOptions(
                resetOnError: true,
                encryptedSharedPreferences: true,
              ),
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

    // Persist to FlutterSecureStorage
    try {
      await _secureStorage.write(key: _kAccessToken, value: access);
      await _secureStorage.write(key: _kRefreshToken, value: refresh);
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage save error: $e');
    }

    // Dual-write to SharedPreferences as backup
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessToken, access);
      await prefs.setString(_kRefreshToken, refresh);
    } catch (e) {
      debugPrint('[ApiClient] SharedPreferences backup save error: $e');
    }
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_kAccessToken);
        if (token != null && token.isNotEmpty) {
          _cachedAccessToken = token;
          return token;
        }
      } catch (e) {
        debugPrint('[ApiClient] Web SharedPreferences read error: $e');
      }
    }

    // 1. Read from FlutterSecureStorage
    try {
      final token = await _secureStorage.read(key: _kAccessToken);
      if (token != null && token.isNotEmpty) {
        _cachedAccessToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage read error: $e');
    }

    // 2. Read from SharedPreferences backup
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

    return null;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }

    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_kRefreshToken);
        if (token != null && token.isNotEmpty) {
          _cachedRefreshToken = token;
          return token;
        }
      } catch (e) {
        debugPrint('[ApiClient] Web SharedPreferences read error: $e');
      }
    }

    // 1. Read from FlutterSecureStorage
    try {
      final token = await _secureStorage.read(key: _kRefreshToken);
      if (token != null && token.isNotEmpty) {
        _cachedRefreshToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage read error: $e');
    }

    // 2. Read from SharedPreferences backup
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

    return null;
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;

    try {
      await _secureStorage.delete(key: _kAccessToken);
      await _secureStorage.delete(key: _kRefreshToken);
      await _secureStorage.delete(key: 'bp_cached_user_profile');
    } catch (e) {
      debugPrint('[ApiClient] SecureStorage clear error: $e');
    }

    // Clear backup keys from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove('bp_cached_user_profile');
    } catch (_) {}
  }

  // ── Authentication ──

  /// Calls `/api/token/` with phone as username and password, storing tokens on success.
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final activeBase = ApiConfig.baseUrl;
    final orderedCandidates = <String>[
      activeBase,
      ...ApiConfig.candidateUrls.where((c) => c != activeBase),
    ];

    ApiException? lastError;

    for (final candidateBase in orderedCandidates) {
      try {
        final cleanPath = 'token/';
        final fullUrl = '$candidateBase/api/$cleanPath';
        final uri = Uri.parse(fullUrl);
        final headers = <String, String>{
          'Content-Type': 'application/json',
        };
        if (!kIsWeb) {
          final deviceId = await getDeviceId();
          headers['X-Device-ID'] = deviceId;
          headers['X-Device-Name'] = getDeviceName();
          headers['X-Platform'] = getPlatform();
        }
        final response = await _client
            .post(
              uri,
              headers: headers,
              body: jsonEncode({
                'username': phone,
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          ApiConfig.overrideBaseUrl(candidateBase);
          baseUrl = candidateBase;
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
        debugPrint('[ApiClient] Login SocketException on $candidateBase: $e');
        lastError = ApiException('Network unreachable. Please check your internet connection.', rawError: e);
        continue;
      } on TimeoutException catch (e) {
        debugPrint('[ApiClient] Login TimeoutException on $candidateBase');
        lastError = ApiException('Connection timed out. Server took too long to respond.', rawError: e);
        continue;
      } on http.ClientException catch (e) {
        debugPrint('[ApiClient] Login ClientException on $candidateBase: $e');
        lastError = ApiException('Network unreachable. Please check your internet connection.', rawError: e);
        continue;
      } catch (e) {
        debugPrint('[ApiClient] Login unexpected error on $candidateBase: $e');
        lastError = ApiException('Unexpected authentication error: $e', rawError: e);
        continue;
      }
    }

    throw lastError ?? const ApiException('Network unreachable. Please check your internet connection.');
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
        final friendlyMessage = _extractErrorMessage(response.body, statusCode: response.statusCode);
        throw ApiException(
          friendlyMessage,
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

  Completer<String?>? _refreshCompleter;

  /// Attempts to refresh the access token using the stored refresh token.
  /// Uses a single-flight lock so concurrent 401s wait for the exact same refresh request.
  /// Only clears session/logs out if the server returns 401 (refresh token expired/invalid).
  /// Network errors, timeouts, or 5xx server issues will NEVER clear tokens or log out.
  Future<String?> refreshToken() async {
    // Single-flight lock: if a refresh is already in-flight, await the same future
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refresh = await getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        completer.complete(null);
        return null;
      }

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
          completer.complete(newAccess);
          return newAccess;
        }
      } else if (response.statusCode == 401) {
        // Refresh token itself is invalid or expired → clear session
        debugPrint('[ApiClient] Refresh token invalid/expired (401). Clearing session.');
        await clearTokens();
        onSessionExpired?.call();
        completer.complete(null);
        return null;
      } else {
        // 5xx server gateway or 429 rate limit: do NOT log out!
        debugPrint('[ApiClient] Token refresh returned status ${response.statusCode}. Preserving session.');
        completer.complete(null);
        return null;
      }

      completer.complete(null);
      return null;
    } on SocketException catch (e) {
      // Network error must NOT log the user out!
      debugPrint('[ApiClient] Network error during token refresh: $e. Preserving session.');
      completer.complete(null);
      return null;
    } on TimeoutException catch (e) {
      // Timeout must NOT log the user out!
      debugPrint('[ApiClient] Timeout during token refresh: $e. Preserving session.');
      completer.complete(null);
      return null;
    } catch (e) {
      debugPrint('[ApiClient] Token refresh error: $e. Preserving session.');
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
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

  /// Uploads raw file bytes via multipart/form-data with authentication.
  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    required List<int> fileBytes,
    required String filename,
    String fieldName = 'file',
    Map<String, String>? additionalFields,
  }) async {
    final token = await getAccessToken();
    final uri = Uri.parse(_normalizeUrl(path));
    final request = http.MultipartRequest('POST', uri);

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (additionalFields != null) {
      request.fields.addAll(additionalFields);
    }

    final ext = filename.split('.').last.toLowerCase();
    http_parser.MediaType mediaType;
    if (ext == 'png') {
      mediaType = http_parser.MediaType('image', 'png');
    } else if (ext == 'webp') {
      mediaType = http_parser.MediaType('image', 'webp');
    } else {
      mediaType = http_parser.MediaType('image', 'jpeg');
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: filename,
        contentType: mediaType,
      ),
    );

    final streamedResponse = await _client.send(request).timeout(connectTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final msg = _extractErrorMessage(response.body, statusCode: response.statusCode);
      throw ApiException(msg, statusCode: response.statusCode, rawError: response.body);
    }
  }

  /// Uploads fields and optional raw file bytes via multipart/form-data.
  /// Fully cross-platform compatible across Flutter Web (memory bytes) and native platforms.
  Future<http.Response> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<int>? fileBytes,
    String? filename,
    String fileFieldName = 'requisition_slip',
    List<int>? secondFileBytes,
    String? secondFilename,
    String secondFileFieldName = 'patient_photo',
  }) async {
    final authHeaders = await _getAuthHeaders();
    final uri = Uri.parse(_normalizeUrl(path));
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(authHeaders);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    if (fileBytes != null && fileBytes.isNotEmpty) {
      final fname = filename ?? 'document.jpg';
      final ext = fname.split('.').last.toLowerCase();
      http_parser.MediaType mediaType;
      if (ext == 'png') {
        mediaType = http_parser.MediaType('image', 'png');
      } else if (ext == 'webp') {
        mediaType = http_parser.MediaType('image', 'webp');
      } else {
        mediaType = http_parser.MediaType('image', 'jpeg');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          fileFieldName,
          fileBytes,
          filename: fname,
          contentType: mediaType,
        ),
      );
    }

    if (secondFileBytes != null && secondFileBytes.isNotEmpty) {
      final fname = secondFilename ?? 'photo.jpg';
      final ext = fname.split('.').last.toLowerCase();
      http_parser.MediaType mediaType;
      if (ext == 'png') {
        mediaType = http_parser.MediaType('image', 'png');
      } else if (ext == 'webp') {
        mediaType = http_parser.MediaType('image', 'webp');
      } else {
        mediaType = http_parser.MediaType('image', 'jpeg');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          secondFileFieldName,
          secondFileBytes,
          filename: fname,
          contentType: mediaType,
        ),
      );
    }

    final streamedResponse = await _client.send(request).timeout(connectTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 400) {
      final msg = _extractErrorMessage(response.body, statusCode: response.statusCode);
      throw ApiException(msg, statusCode: response.statusCode, rawError: response.body);
    }
    return response;
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
      return await InstitutionService.instance.search(query);
    } catch (e) {
      debugPrint('[ApiClient] Failed to load local institutions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUpazilas(String query, {String? district}) async {
    try {
      final qParam = Uri.encodeComponent(query);
      final distParam = (district != null && district.isNotEmpty) ? '&district=${Uri.encodeComponent(district)}' : '';
      final response = await _client
          .get(Uri.parse(_normalizeUrl('locations/upazila-search/?q=$qParam$distParam')))
          .timeout(connectTimeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = data.cast<Map<String, dynamic>>();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    if (district != null && district.isNotEmpty) {
      final localUpz = getUpazilasForDistrict(district);
      final qLower = query.toLowerCase();
      final filtered = qLower.isEmpty
          ? localUpz
          : localUpz.where((u) => u.toLowerCase().contains(qLower)).toList();
      return filtered.map((u) => {'id': null, 'name': u, 'district_id': null}).toList();
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
      try {
        final body = jsonDecode(response.body);
        final code = body['code'];
        final msg = body['message'] ?? body['detail'] ?? body['error'] ?? 'Failed to request OTP';
        if (response.statusCode == 503 || code == 'EMAIL_UNAVAILABLE') {
          throw EmailUnavailableException(msg);
        }
        throw ApiException(msg, statusCode: response.statusCode);
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException('Failed to request OTP', statusCode: response.statusCode);
      }
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

  // ─── Blood Request Submit Email OTP (Phase 3) ───

  Future<Map<String, dynamic>> sendRequestOtp({String? email}) async {
    try {
      final response = await post(
        'requests/otp/send/',
        body: {
          if (email != null && email.isNotEmpty) 'email': email,
        },
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiException catch (e) {
      String msg = e.message;
      int cooldown = 60;
      if (e.rawError is String) {
        try {
          final decoded = jsonDecode(e.rawError as String);
          if (decoded is Map) {
            msg = decoded['error']?.toString() ?? decoded['detail']?.toString() ?? msg;
            if (decoded['cooldown_seconds'] != null) {
              cooldown = (decoded['cooldown_seconds'] as num).toInt();
            }
          }
        } catch (_) {}
      }
      throw RequestOtpException(
        msg,
        statusCode: e.statusCode,
        rawError: e.rawError,
        cooldownSeconds: cooldown,
      );
    }
  }

  Future<String> verifyRequestOtp({required String code, String? email}) async {
    try {
      final response = await post(
        'requests/otp/verify/',
        body: {
          'code': code.trim(),
          if (email != null && email.isNotEmpty) 'email': email.trim(),
        },
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['submit_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException('No submit token received from server verification.');
      }
      return token;
    } on ApiException catch (e) {
      String msg = e.message;
      int remainingAttempts = 5;
      if (e.rawError is String) {
        try {
          final decoded = jsonDecode(e.rawError as String);
          if (decoded is Map) {
            msg = decoded['error']?.toString() ?? decoded['detail']?.toString() ?? msg;
            if (decoded['remaining_attempts'] != null) {
              remainingAttempts = (decoded['remaining_attempts'] as num).toInt();
            }
          }
        } catch (_) {}
      }
      throw RequestOtpException(
        msg,
        statusCode: e.statusCode,
        rawError: e.rawError,
        remainingAttempts: remainingAttempts,
      );
    }
  }

  String _normalizeUrl(String path) {
    return ApiConfig.resolveUrl(path);
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{};
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (!kIsWeb) {
      final deviceId = await getDeviceId();
      headers['X-Device-ID'] = deviceId;
      headers['X-Device-Name'] = getDeviceName();
      headers['X-Platform'] = getPlatform();
    }
    return headers;
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> authHeaders) requestFn, {
    int maxAttempts = 3,
  }) async {
    final activeBase = ApiConfig.baseUrl;
    final orderedCandidates = <String>[
      activeBase,
      ...ApiConfig.candidateUrls.where((c) => c != activeBase),
    ];
    int candidateIdx = 0;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final authHeaders = await _getAuthHeaders();
        http.Response response = await requestFn(authHeaders).timeout(receiveTimeout);

        // Cold-start / gateway retry for Render proxy (only retry once if non-JSON gateway error)
        final isGatewayError = (response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504);
        final isAppJson = response.headers['content-type']?.contains('application/json') ?? response.body.trim().startsWith('{');
        if (isGatewayError && !isAppJson) {
          if (attempt < 2) {
            debugPrint('[ApiClient] Server cold-start gateway status ${response.statusCode}. Auto-retrying once in 2000ms...');
            await Future.delayed(const Duration(milliseconds: 2000));
            continue;
          }
          throw const ApiException(
            'Server is waking up, please wait a moment... (সার্ভার চালু হচ্ছে, কিছুক্ষণ অপেক্ষা করুন...)',
            statusCode: 503,
          );
        }

        if (response.statusCode == 401) {
          final newToken = await refreshToken();
          if (newToken != null) {
            final newAuthHeaders = await _getAuthHeaders();
            response = await requestFn(newAuthHeaders).timeout(receiveTimeout);
          }
        }

        if (response.statusCode == 401) {
          throw ApiException(
            'Session expired or unauthorized. Please log in again.',
            statusCode: 401,
            rawError: response.body,
          );
        }

        if (response.statusCode >= 400) {
          final friendlyMessage = _extractErrorMessage(response.body, statusCode: response.statusCode);
          throw ApiException(
            friendlyMessage,
            statusCode: response.statusCode,
            rawError: response.body,
          );
        }

        if (candidateIdx > 0 && response.statusCode >= 200 && response.statusCode < 400) {
          final winningHost = orderedCandidates[candidateIdx];
          ApiConfig.overrideBaseUrl(winningHost);
          baseUrl = winningHost;
        }

        return response;
      } on ApiException {
        rethrow;
      } on SocketException catch (e) {
        if (candidateIdx < orderedCandidates.length - 1) {
          candidateIdx++;
          final nextHost = orderedCandidates[candidateIdx];
          debugPrint('[ApiClient] SocketException. Trying next candidate endpoint $nextHost...');
          baseUrl = nextHost;
          continue;
        }
        if (attempt < maxAttempts) {
          debugPrint('[ApiClient] SocketException on attempt $attempt. Retrying in 2.5s...');
          await Future.delayed(const Duration(milliseconds: 2500));
          continue;
        }
        throw ApiException('Network connection failed. Please check your network.', rawError: e);
      } on TimeoutException catch (e) {
        if (candidateIdx < orderedCandidates.length - 1) {
          candidateIdx++;
          final nextHost = orderedCandidates[candidateIdx];
          debugPrint('[ApiClient] TimeoutException. Trying next candidate endpoint $nextHost...');
          baseUrl = nextHost;
          continue;
        }
        if (attempt < maxAttempts) {
          final backoffMs = attempt * 2000;
          debugPrint('[ApiClient] TimeoutException on attempt $attempt. Retrying in ${backoffMs}ms...');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        throw ApiException('Server is waking up, please wait a moment... (সার্ভার চালু হচ্ছে, কিছুক্ষণ অপেক্ষা করুন...)', statusCode: 504, rawError: e);
      } on FormatException catch (e) {
        throw ApiException('Malformed response format received.', rawError: e);
      } on http.ClientException catch (e) {
        if (candidateIdx < orderedCandidates.length - 1) {
          candidateIdx++;
          final nextHost = orderedCandidates[candidateIdx];
          debugPrint('[ApiClient] ClientException. Trying next candidate endpoint $nextHost...');
          baseUrl = nextHost;
          continue;
        }
        if (attempt < maxAttempts) {
          debugPrint('[ApiClient] ClientException on attempt $attempt. Retrying in 2.5s...');
          await Future.delayed(const Duration(milliseconds: 2500));
          continue;
        }
        throw ApiException('HTTP client error: ${e.message}', rawError: e);
      } catch (e) {
        throw ApiException('Network request error: $e', rawError: e);
      }
    }
    throw const ApiException('Network connection failed after retries.');
  }

  /// Fetches public statistics with a strict 3-second timeout.
  /// Caches the result in SharedPreferences for offline resilience.
  /// Never throws: returns cached stats on error/timeout, or null if never cached.
  Future<Map<String, int>?> getPublicStats() async {
    const String cacheKeyRegistered = 'bp_public_stats_registered_donors';
    const String cacheKeyDistricts = 'bp_public_stats_districts_covered';

    try {
      final uri = Uri.parse(_normalizeUrl('public/stats/'));
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final registered = (data['registered_donors'] as num?)?.toInt() ?? 0;
          final districts = (data['districts_covered'] as num?)?.toInt() ?? 0;

          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(cacheKeyRegistered, registered);
            await prefs.setInt(cacheKeyDistricts, districts);
          } catch (_) {}

          return {
            'registered_donors': registered,
            'districts_covered': districts,
          };
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] getPublicStats failed or timed out: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(cacheKeyRegistered) && prefs.containsKey(cacheKeyDistricts)) {
        return {
          'registered_donors': prefs.getInt(cacheKeyRegistered) ?? 0,
          'districts_covered': prefs.getInt(cacheKeyDistricts) ?? 0,
        };
      }
    } catch (_) {}

    return null;
  }

  /// Fetches active devices and sessions from `/api/account/devices/`.
  Future<List<Map<String, dynamic>>> getDevices() async {
    final response = await get('account/devices/');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['devices'] as List<dynamic>?) ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(
      _extractErrorMessage(response.body, statusCode: response.statusCode),
      statusCode: response.statusCode,
      rawError: response.body,
    );
  }

  /// Revokes a device session by ID from `/api/account/devices/<id>/revoke/`.
  Future<void> revokeDevice(int deviceId) async {
    final refresh = await getRefreshToken();
    final response = await post(
      'account/devices/$deviceId/revoke/',
      body: {'refresh': refresh},
    );
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(response.body, statusCode: response.statusCode),
        statusCode: response.statusCode,
        rawError: response.body,
      );
    }
  }

  /// Revokes all other sessions from `/api/account/devices/logout-all/`.
  Future<void> logoutAllDevices({bool includeCurrent = false}) async {
    final refresh = await getRefreshToken();
    final response = await post(
      'account/devices/logout-all/?include_current=$includeCurrent',
      body: {'refresh': refresh},
    );
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(response.body, statusCode: response.statusCode),
        statusCode: response.statusCode,
        rawError: response.body,
      );
    }
    if (includeCurrent) {
      await clearTokens();
    }
  }

  /// Changes the user's password and revokes other sessions.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final refresh = await getRefreshToken();
    final response = await post(
      'auth/password-change/',
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
        if (refresh != null) 'refresh': refresh,
      },
    );
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(response.body, statusCode: response.statusCode),
        statusCode: response.statusCode,
        rawError: response.body,
      );
    }
  }

  static String _extractErrorMessage(String responseBody, {int? statusCode}) {
    if (responseBody.trim().startsWith('<!DOCTYPE html>') || responseBody.contains('<html')) {
      if (statusCode == 404) {
        return 'Service not found, please update the app';
      } else if (statusCode != null && statusCode >= 500) {
        return 'Server problem, please try again shortly';
      }
      return 'Unexpected server response. Please try again.';
    }

    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map) {
        // Standard DRF single-key errors
        if (decoded.containsKey('detail')) return decoded['detail'].toString();
        if (decoded.containsKey('message')) return decoded['message'].toString();
        if (decoded.containsKey('error')) return decoded['error'].toString();

        // DRF field-level validation errors: {"field": ["msg1", "msg2"], ...}
        // Extract all messages and join them into one readable string.
        final parts = <String>[];
        for (final entry in decoded.entries) {
          final val = entry.value;
          if (val is List) {
            parts.add(val.map((v) => v.toString()).join(' '));
          } else {
            parts.add(val.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' | ');
      }
    } catch (_) {
      if (statusCode == 404) {
        return 'Service not found, please update the app';
      } else if (statusCode != null && statusCode >= 500) {
        return 'Server problem, please try again shortly';
      }
    }
    return responseBody.length > 100 ? '${responseBody.substring(0, 100)}...' : responseBody;
  }

  static bool? _cachedRequestOtpRequired;
  static DateTime? _cachedRequestOtpRequiredAt;

  static set staticRequestOtpRequired(bool? val) {
    _cachedRequestOtpRequired = val;
    _cachedRequestOtpRequiredAt = val != null ? DateTime.now() : null;
  }

  bool? get cachedRequestOtpRequired => _cachedRequestOtpRequired;

  Future<bool> getRequestOtpRequired() async {
    final now = DateTime.now();
    if (_cachedRequestOtpRequired != null &&
        _cachedRequestOtpRequiredAt != null &&
        now.difference(_cachedRequestOtpRequiredAt!).inMinutes < 5) {
      return _cachedRequestOtpRequired!;
    }
    try {
      final res = await get('public/config/').timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data.containsKey('request_otp_required')) {
          _cachedRequestOtpRequired = data['request_otp_required'] == true;
          _cachedRequestOtpRequiredAt = now;
          return _cachedRequestOtpRequired!;
        }
      }
    } catch (_) {}
    // Config fail-safe: if GET /api/public/config/ fails or is slow, treat request_otp_required as false
    return false;
  }
}

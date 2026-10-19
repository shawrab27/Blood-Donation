// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/foundation.dart';

/// Supported deployment environments/flavors for BloodPulse API
enum ApiFlavor {
  lanDev,
  rehearsal,
  prod,
  local,
}

/// Central ApiConfig defining single source of truth for backend endpoints.
class ApiConfig {
  ApiConfig._();

  static const String _defaultUrl = 'https://bloodpulse-backend.onrender.com';
  static const String _renderUrl = 'https://bloodpulse-backend.onrender.com';
  static const String _lanDefault = 'http://192.168.0.103:8000';
  static const String _adbDefault = 'http://127.0.0.1:8000';

  static String? _overrideBaseUrl;

  /// Dynamic candidates for fallback resilience on mobile/local network.
  static List<String> get candidateUrls {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const flavor = String.fromEnvironment('API_FLAVOR', defaultValue: 'prod');
    if (flavor == 'local' || flavor == 'localhost' || defined.contains('127.0.0.1') || defined.contains('localhost')) {
      final base = defined.isNotEmpty ? _clean(defined) : _clean(_adbDefault);
      return [base, 'http://localhost:8000', _clean(_adbDefault)];
    }
    if (flavor == 'lan' || flavor == 'lan-dev') {
      return [_clean(_lanDefault), _clean(_defaultUrl)];
    }
    if (flavor == 'adb') {
      return [_clean(_adbDefault), _clean(_defaultUrl)];
    }
    return [
      _clean(_defaultUrl),
    ];
  }

  static void overrideBaseUrl(String url) {
    final cleaned = _clean(url);
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const flavor = String.fromEnvironment('API_FLAVOR', defaultValue: 'prod');
    final isLocal = flavor == 'adb' || flavor == 'local' || flavor == 'localhost' || defined.contains('127.0.0.1') || defined.contains('localhost');
    if (!isLocal && (cleaned.contains('127.0.0.1') || cleaned.contains('localhost'))) {
      if (kDebugMode) {
        debugPrint('[ApiConfig] Rejected overriding baseUrl to localhost in non-adb flavor: $cleaned');
      }
      return;
    }
    if (cleaned.isNotEmpty) {
      _overrideBaseUrl = cleaned;
      if (kDebugMode) {
        debugPrint('[ApiConfig] Base URL overridden to: $_overrideBaseUrl');
      }
    }
  }

  static void resetOverride() {
    _overrideBaseUrl = null;
  }

  /// Resolves the current base URL from override, `--dart-define=API_BASE_URL` or flavor.
  static String get baseUrl {
    if (_overrideBaseUrl != null && _overrideBaseUrl!.isNotEmpty) {
      return _overrideBaseUrl!;
    }

    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) {
      return _clean(defined);
    }

    const flavor = String.fromEnvironment('API_FLAVOR', defaultValue: 'prod');
    switch (flavor) {
      case 'local':
      case 'localhost':
      case 'adb':
        return _adbDefault;
      case 'lan':
      case 'lan-dev':
        return _lanDefault;
      case 'rehearsal':
        return _renderUrl;
      case 'prod':
      default:
        return _defaultUrl;
    }
  }

  static String _clean(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Resolves an API path to a fully qualified URL starting with `/api/`.
  static String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    var cleanPath = path.trim();
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.startsWith('api/')) cleanPath = cleanPath.substring(4);
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);

    final base = baseUrl;
    final full = '$base/api/$cleanPath';
    if (kDebugMode) {
      debugPrint('[ApiConfig] Resolved: $path -> $full');
    }
    return full;
  }
}

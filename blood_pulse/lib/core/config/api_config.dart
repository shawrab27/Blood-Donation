// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/foundation.dart';

/// Supported deployment environments/flavors for BloodPulse API
enum ApiFlavor {
  lanDev,
  rehearsal,
  prod,
}

/// Central ApiConfig defining single source of truth for backend endpoints.
class ApiConfig {
  ApiConfig._();

  static const String _defaultUrl = 'https://bloodpulse-backend.onrender.com';
  static const String _renderUrl = 'https://bloodpulse-backend.onrender.com';
  static const String _lanDefault = 'http://192.168.0.105:8000';

  /// Resolves the current base URL from `--dart-define=API_BASE_URL` or flavor.
  static String get baseUrl {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) {
      return _clean(defined);
    }

    const flavor = String.fromEnvironment('API_FLAVOR', defaultValue: 'prod');
    switch (flavor) {
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

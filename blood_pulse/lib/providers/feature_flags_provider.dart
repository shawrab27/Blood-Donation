// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

/// State of feature flags fetched from /api/public/config/
class FeatureFlagsState {
  final Map<String, bool> flags;
  final bool isLoading;
  final bool hasError;

  const FeatureFlagsState({
    this.flags = const {},
    this.isLoading = false,
    this.hasError = false,
  });

  /// Returns true only if flag is explicitly true.
  /// Safe default: false on any cold start, error, or missing flag.
  bool isEnabled(String flagName) {
    return flags[flagName] == true;
  }

  FeatureFlagsState copyWith({
    Map<String, bool>? flags,
    bool? isLoading,
    bool? hasError,
  }) {
    return FeatureFlagsState(
      flags: flags ?? this.flags,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

class FeatureFlagsNotifier extends StateNotifier<FeatureFlagsState> {
  final ApiClient _apiClient;

  FeatureFlagsNotifier({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        super(const FeatureFlagsState(isLoading: true)) {
    loadFlags();
  }

  Future<void> loadFlags() async {
    try {
      final res = await _apiClient.get('public/config/').timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['flags'] is Map) {
          final Map<String, dynamic> rawFlags = data['flags'];
          final Map<String, bool> parsed = {};
          rawFlags.forEach((key, value) {
            parsed[key] = value == true;
          });
          state = FeatureFlagsState(
            flags: parsed,
            isLoading: false,
            hasError: false,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false, hasError: true);
    } catch (e) {
      debugPrint('[FeatureFlags] Error loading flags: $e. Safe default false applied.');
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  /// Safe lookup with default false
  bool isEnabled(String flagName) => state.isEnabled(flagName);
}

final featureFlagsProvider =
    StateNotifierProvider<FeatureFlagsNotifier, FeatureFlagsState>((ref) {
  return FeatureFlagsNotifier();
});

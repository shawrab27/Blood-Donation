// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../services/api_client.dart';

class UserLocationState {
  final int? currentDistrictId;
  final String? districtName;
  final int? divisionId;
  final String? divisionName;
  final String source; // 'gps' | 'profile' | 'manual'
  final bool changed;
  final DateTime? updatedAt;

  const UserLocationState({
    this.currentDistrictId,
    this.districtName,
    this.divisionId,
    this.divisionName,
    this.source = 'profile',
    this.changed = false,
    this.updatedAt,
  });

  UserLocationState copyWith({
    int? currentDistrictId,
    String? districtName,
    int? divisionId,
    String? divisionName,
    String? source,
    bool? changed,
    DateTime? updatedAt,
  }) {
    return UserLocationState(
      currentDistrictId: currentDistrictId ?? this.currentDistrictId,
      districtName: districtName ?? this.districtName,
      divisionId: divisionId ?? this.divisionId,
      divisionName: divisionName ?? this.divisionName,
      source: source ?? this.source,
      changed: changed ?? this.changed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserLocationNotifier extends StateNotifier<UserLocationState> {
  UserLocationNotifier() : super(const UserLocationState()) {
    initLocation();
  }

  final ApiClient _apiClient = ApiClient();
  DateTime? _lastSyncTime;
  Position? _lastPosition;

  Future<void> initLocation() async {
    try {
      // 1. Fetch current backend stored location state
      final res = await _apiClient.get('users/location/');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        state = UserLocationState(
          currentDistrictId: data['current_district_id'] as int?,
          districtName: data['district_name'] as String?,
          divisionId: data['division_id'] as int?,
          divisionName: data['division_name'] as String?,
          source: data['source']?.toString() ?? 'profile',
          changed: data['changed'] as bool? ?? false,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[UserLocationNotifier] Initial location fetch note: $e');
    }

    // 2. Coarse GPS check with permission guard
    await refreshCoarseLocation();
  }

  Future<bool> refreshCoarseLocation({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastSyncTime != null && now.difference(_lastSyncTime!).inMinutes < 30) {
      return false;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Do not spam request if user denied
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 6),
      );

      // Check distance threshold > 5km from last sync
      if (!force && _lastPosition != null) {
        final distMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (distMeters < 5000) {
          return false;
        }
      }

      _lastPosition = pos;
      _lastSyncTime = now;

      final res = await _apiClient.post('users/location/', body: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'source': 'gps',
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final bool districtChanged = data['changed'] as bool? ?? false;
        state = UserLocationState(
          currentDistrictId: data['current_district_id'] as int?,
          districtName: data['district_name'] as String?,
          divisionId: data['division_id'] as int?,
          divisionName: data['division_name'] as String?,
          source: 'gps',
          changed: districtChanged,
          updatedAt: now,
        );
        return districtChanged;
      }
    } catch (e) {
      debugPrint('[UserLocationNotifier] Coarse GPS location sync note: $e');
    }
    return false;
  }

  void acknowledgeDistrictChange() {
    state = state.copyWith(changed: false);
  }

  void setManualDistrict(int districtId, String districtName) {
    state = state.copyWith(
      currentDistrictId: districtId,
      districtName: districtName,
      source: 'manual',
      changed: false,
      updatedAt: DateTime.now(),
    );
  }
}

final userLocationProvider = StateNotifierProvider<UserLocationNotifier, UserLocationState>((ref) {
  return UserLocationNotifier();
});

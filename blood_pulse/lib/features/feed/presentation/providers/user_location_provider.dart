// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../services/api_client.dart';

const Map<String, (double, double)> _kDistrictCentroids = {
  // Dhaka Division (13)
  'Dhaka': (23.8103, 90.4125),
  'Faridpur': (23.6070, 89.8429),
  'Gazipur': (24.0022, 90.4264),
  'Gopalganj': (23.0051, 89.8266),
  'Kishoreganj': (24.4449, 90.7766),
  'Madaripur': (23.1641, 90.1897),
  'Manikganj': (23.8617, 90.0003),
  'Munshiganj': (23.5422, 90.5305),
  'Narayanganj': (23.6238, 90.5000),
  'Narsingdi': (23.9193, 90.7176),
  'Rajbari': (23.7574, 89.6445),
  'Shariatpur': (23.2423, 90.3540),
  'Tangail': (24.2513, 89.9167),

  // Chattogram Division (11)
  'Bandarban': (22.1953, 92.2184),
  'Brahmanbaria': (23.9571, 91.1115),
  'Chandpur': (23.2333, 90.6667),
  'Chattogram': (22.3569, 91.7832),
  "Cox's Bazar": (21.4272, 92.0058),
  'Cumilla': (23.4607, 91.1809),
  'Feni': (23.0186, 91.3966),
  'Khagrachhari': (23.1193, 91.9847),
  'Lakshmipur': (22.9425, 90.8412),
  'Noakhali': (22.8696, 91.0994),
  'Rangamati': (22.6533, 92.1753),

  // Rajshahi Division (8)
  'Bogura': (24.8465, 89.3770),
  'Chapai Nawabganj': (24.5965, 88.2775),
  'Joypurhat': (25.1015, 89.0277),
  'Naogaon': (24.8109, 88.9416),
  'Natore': (24.4206, 88.9324),
  'Pabna': (24.0064, 89.2372),
  'Rajshahi': (24.3745, 88.6042),
  'Sirajganj': (24.4534, 89.7008),

  // Khulna Division (10)
  'Bagerhat': (22.6516, 89.7859),
  'Chuadanga': (23.6402, 88.8418),
  'Jashore': (23.1664, 89.2081),
  'Jhenaidah': (23.5450, 89.1726),
  'Khulna': (22.8456, 89.5403),
  'Kushtia': (23.9013, 89.1204),
  'Magura': (23.4873, 89.4198),
  'Meherpur': (23.7622, 88.6318),
  'Narail': (23.1725, 89.5127),
  'Satkhira': (22.7185, 89.0705),

  // Barishal Division (6)
  'Barguna': (22.1570, 90.1256),
  'Barishal': (22.7010, 90.3535),
  'Bhola': (22.6859, 90.6481),
  'Jhalokati': (22.6406, 90.1987),
  'Patuakhali': (22.3596, 90.3299),
  'Pirojpur': (22.5841, 89.9720),

  // Sylhet Division (4)
  'Habiganj': (24.3749, 91.4155),
  'Moulvibazar': (24.4829, 91.7774),
  'Sunamganj': (25.0658, 91.3950),
  'Sylhet': (24.8949, 91.8687),

  // Rangpur Division (8)
  'Dinajpur': (25.6217, 88.6355),
  'Gaibandha': (25.3288, 89.5406),
  'Kurigram': (25.8054, 89.6362),
  'Lalmonirhat': (25.9923, 89.2847),
  'Nilphamari': (25.9318, 88.8560),
  'Panchagarh': (26.3411, 88.5542),
  'Rangpur': (25.7439, 89.2752),
  'Thakurgaon': (26.0337, 88.4617),

  // Mymensingh Division (4)
  'Jamalpur': (24.9375, 89.9378),
  'Mymensingh': (24.7471, 90.4203),
  'Netrokona': (24.8709, 90.7279),
  'Sherpur': (25.0205, 90.0153),
};

const Map<String, String> _kDistrictToDivision = {
  'Dhaka': 'Dhaka', 'Faridpur': 'Dhaka', 'Gazipur': 'Dhaka', 'Gopalganj': 'Dhaka', 'Kishoreganj': 'Dhaka',
  'Madaripur': 'Dhaka', 'Manikganj': 'Dhaka', 'Munshiganj': 'Dhaka', 'Narayanganj': 'Dhaka', 'Narsingdi': 'Dhaka',
  'Rajbari': 'Dhaka', 'Shariatpur': 'Dhaka', 'Tangail': 'Dhaka',

  'Bandarban': 'Chattogram', 'Brahmanbaria': 'Chattogram', 'Chandpur': 'Chattogram', 'Chattogram': 'Chattogram',
  "Cox's Bazar": 'Chattogram', 'Cumilla': 'Chattogram', 'Feni': 'Chattogram', 'Khagrachhari': 'Chattogram',
  'Lakshmipur': 'Chattogram', 'Noakhali': 'Chattogram', 'Rangamati': 'Chattogram',

  'Bogura': 'Rajshahi', 'Chapai Nawabganj': 'Rajshahi', 'Joypurhat': 'Rajshahi', 'Naogaon': 'Rajshahi',
  'Natore': 'Rajshahi', 'Pabna': 'Rajshahi', 'Rajshahi': 'Rajshahi', 'Sirajganj': 'Rajshahi',

  'Bagerhat': 'Khulna', 'Chuadanga': 'Khulna', 'Jashore': 'Khulna', 'Jhenaidah': 'Khulna', 'Khulna': 'Khulna',
  'Kushtia': 'Khulna', 'Magura': 'Khulna', 'Meherpur': 'Khulna', 'Narail': 'Khulna', 'Satkhira': 'Khulna',

  'Barguna': 'Barishal', 'Barishal': 'Barishal', 'Bhola': 'Barishal', 'Jhalokati': 'Barishal',
  'Patuakhali': 'Barishal', 'Pirojpur': 'Barishal',

  'Habiganj': 'Sylhet', 'Moulvibazar': 'Sylhet', 'Sunamganj': 'Sylhet', 'Sylhet': 'Sylhet',

  'Dinajpur': 'Rangpur', 'Gaibandha': 'Rangpur', 'Kurigram': 'Rangpur', 'Lalmonirhat': 'Rangpur',
  'Nilphamari': 'Rangpur', 'Panchagarh': 'Rangpur', 'Rangpur': 'Rangpur', 'Thakurgaon': 'Rangpur',

  'Jamalpur': 'Mymensingh', 'Mymensingh': 'Mymensingh', 'Netrokona': 'Mymensingh', 'Sherpur': 'Mymensingh',
};

String? _findNearestDistrict(double lat, double lng) {
  double minDistance = double.infinity;
  String? nearest;

  for (final entry in _kDistrictCentroids.entries) {
    final cLat = entry.value.$1;
    final cLng = entry.value.$2;
    final dLat = (cLat - lat) * math.pi / 180.0;
    final dLng = (cLng - lng) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat * math.pi / 180.0) *
            math.cos(cLat * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final dist = 6371.0 * c;
    if (dist < minDistance) {
      minDistance = dist;
      nearest = entry.key;
    }
  }
  return nearest;
}

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
  Position? get lastPosition => _lastPosition;

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
    if (!force && _lastSyncTime != null && now.difference(_lastSyncTime!).inMinutes < 15) {
      return false;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[UserLocationNotifier] Location services disabled.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[UserLocationNotifier] Location permission denied by user.');
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[UserLocationNotifier] Location permission permanently denied.');
        return false;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        debugPrint('[UserLocationNotifier] getCurrentPosition timed out: $e, falling back to last known.');
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        debugPrint('[UserLocationNotifier] Could not obtain GPS position.');
        return false;
      }

      _lastPosition = pos;
      _lastSyncTime = now;

      // 1. Instantly resolve nearest canonical district locally
      final localNearest = _findNearestDistrict(pos.latitude, pos.longitude);
      final localDivision = localNearest != null ? _kDistrictToDivision[localNearest] : null;

      if (localNearest != null) {
        final bool isChanged = state.districtName != null && state.districtName != localNearest;
        state = state.copyWith(
          districtName: localNearest,
          divisionName: localDivision,
          source: 'gps',
          changed: isChanged,
          updatedAt: now,
        );
      }

      // 2. Sync with backend API
      try {
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
            districtName: data['district_name'] as String? ?? localNearest,
            divisionId: data['division_id'] as int?,
            divisionName: data['division_name'] as String? ?? localDivision,
            source: 'gps',
            changed: districtChanged || (state.changed),
            updatedAt: now,
          );
          return districtChanged;
        }
      } catch (apiErr) {
        debugPrint('[UserLocationNotifier] Backend location sync note: $apiErr (local GPS district $localNearest preserved)');
      }

      return localNearest != null;
    } catch (e) {
      debugPrint('[UserLocationNotifier] refreshCoarseLocation error: $e');
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

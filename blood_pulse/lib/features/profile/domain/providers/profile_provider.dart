// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/profile_models.dart';
import '../../../../services/api_client.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel?>>((ref) {
  // Re-fetch or reset profile whenever user authentication status changes
  ref.watch(authProvider.select((s) => s.status));
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  ProfileNotifier() : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  /// Fetches the current authenticated user's own profile via GET /api/donors/me/
  /// Verifies access token first to avoid premature 401 Unauthorized errors for guests.
  Future<void> fetchProfile() async {
    try {
      state = const AsyncValue.loading();
      final token = await ApiClient().getAccessToken();
      if (token == null || token.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final response = await ApiClient().get('donors/me/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = ProfileModel.fromJson(data);
        state = AsyncValue.data(profile);
      } else if (response.statusCode == 404 || response.statusCode == 401) {
        state = const AsyncValue.data(null);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final currentProfile = state.value;
    if (currentProfile == null) return false;

    try {
      final response = await ApiClient().patch(
        'donors/${currentProfile.id}/',
        body: data,
      );

      if (response.statusCode == 200) {
        final updatedProfile = ProfileModel.fromJson(jsonDecode(response.body));
        state = AsyncValue.data(updatedProfile);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print(e);
      return false;
    }
  }
}

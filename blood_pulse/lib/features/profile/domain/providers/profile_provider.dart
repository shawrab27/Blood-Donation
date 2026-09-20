import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/profile_models.dart';
import '../../../../services/api_client.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel?>>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  ProfileNotifier() : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  final String _baseUrl = 'https://blood-donation-liard.vercel.app/api';


  /// Fetches the current authenticated user's own profile via GET /api/donors/me/
  /// This prevents the bug where data[0] of the list always returned the first
  /// user in the database (Dr. S.M. Shawrab) regardless of who was logged in.
  Future<void> fetchProfile() async {
    try {
      state = const AsyncValue.loading();
      final token = await ApiClient().getAccessToken();
      
      if (token == null) {
        state = const AsyncValue.data(null);
        return;
      }

      // First try the /me/ endpoint for the exact current user
      final meResponse = await http.get(
        Uri.parse('$_baseUrl/donors/me/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (meResponse.statusCode == 200) {
        final data = jsonDecode(meResponse.body) as Map<String, dynamic>;
        final profile = ProfileModel.fromJson(data);
        state = AsyncValue.data(profile);
        return;
      }

      // Fallback: If /donors/me/ is not available, do not blindly assign data[0] (which is Dr. S.M. Shawrab)
      // Return null so the app gracefully uses the authenticated user's verified identity from authProvider.
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final currentProfile = state.value;
    if (currentProfile == null) return false;

    try {
      final token = await ApiClient().getAccessToken();
      if (token == null) return false;

      final response = await http.patch(
        Uri.parse('$_baseUrl/donor_profiles/${currentProfile.id}/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
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

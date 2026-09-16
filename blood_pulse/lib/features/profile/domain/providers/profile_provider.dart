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

  // Assuming local dev for now; ideally use a centralized API config
  final String _baseUrl = 'http://127.0.0.1:8000/api';

  Future<void> fetchProfile() async {
    try {
      state = const AsyncValue.loading();
      final token = await ApiClient().getAccessToken();
      
      if (token == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/donor_profiles/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Assuming the user fetches their own profile list which is filtered to 1
          // or we just find the first one. For a real app, it might be /donor_profiles/me/
          final profile = ProfileModel.fromJson(data[0]);
          state = AsyncValue.data(profile);
        } else {
          state = const AsyncValue.data(null);
        }
      } else {
        state = AsyncValue.error('Failed to load profile: ${response.statusCode}', StackTrace.current);
      }
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

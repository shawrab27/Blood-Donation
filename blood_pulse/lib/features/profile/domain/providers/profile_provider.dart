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
      if (!mounted) return;
      state = const AsyncValue.loading();
      final token = await ApiClient().getAccessToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final response = await ApiClient().get('donors/me/');
      if (!mounted) return;
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
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final currentProfile = state.value;
    try {
      final endpoint = (currentProfile != null && currentProfile.id > 0)
          ? 'donors/${currentProfile.id}/'
          : 'donors/me/';
      final response = await ApiClient().patch(
        endpoint,
        body: data,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
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

  /// Toggles 30-day snooze for emergency alerts via PATCH /api/users/me/snooze/
  /// When enabling, sends {"days": 30}. When disabling, sends {"days": null}.
  /// Client never supplies the date. Server recalculates and returns new state.
  Future<bool> setSnooze({required bool enable}) async {
    try {
      final payload = <String, dynamic>{
        'days': enable ? 30 : null,
      };
      final response = await ApiClient().patch('users/me/snooze/', body: payload);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = state.value;
        if (current != null) {
          final updated = ProfileModel(
            id: current.id,
            username: current.username,
            firstName: current.firstName,
            lastName: current.lastName,
            email: current.email,
            bloodGroup: current.bloodGroup,
            district: current.district,
            phoneNumber: current.phoneNumber,
            lastDonationDate: current.lastDonationDate,
            isVerified: current.isVerified,
            isProfileComplete: current.isProfileComplete,
            missingFields: current.missingFields,
            bio: current.bio,
            institute: current.institute,
            address: current.address,
            totalBagsDonated: current.totalBagsDonated,
            profilePicture: current.profilePicture,
            globalRank: current.globalRank,
            badge: current.badge,
            alertPauseUntil: data['alert_pause_until']?.toString(),
            showContact: current.showContact,
            publicProfile: current.publicProfile,
            notificationsEnabled: current.notificationsEnabled,
            emergencyAlertsEnabled: current.emergencyAlertsEnabled,
            donationHistory: current.donationHistory,
            recentLogs: current.recentLogs,
          );
          state = AsyncValue.data(updated);
        } else {
          await fetchProfile();
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print(e);
      return false;
    }
  }
}


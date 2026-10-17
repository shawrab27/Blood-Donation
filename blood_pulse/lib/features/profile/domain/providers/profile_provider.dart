// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/profile_models.dart';
import '../models/donor_review_model.dart';
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

  /// Fetches the current authenticated user's profile via GET /api/profile/me/
  /// (with fallback to /api/donors/me/).
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

      // Try Stage 1B profile/me/ first
      http.Response response = await ApiClient().get('profile/me/');
      if (response.statusCode != 200) {
        // Fallback to legacy donors/me/
        response = await ApiClient().get('donors/me/');
      }

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = ProfileModel.fromJson(data);
        state = AsyncValue.data(profile);
      } else if (response.statusCode == 404 || response.statusCode == 401) {
        state = const AsyncValue.data(null);
      } else {
        throw Exception('Failed to load profile [${response.statusCode}]');
      }
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates profile details via PATCH /api/profile/me/
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient().patch('profile/me/', body: data);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final updatedProfile = ProfileModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        state = AsyncValue.data(updatedProfile);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[updateProfile] Error: $e');
      return false;
    }
  }

  /// Updates last donation date via anti-cheat endpoint PATCH /api/profile/me/last-donation/
  Future<Map<String, dynamic>> updateLastDonationDate(String dateStr) async {
    try {
      final response = await ApiClient().patch(
        'profile/me/last-donation/',
        body: {'last_donation_date': dateStr},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        await fetchProfile();
        return {'success': true, 'data': data};
      } else {
        final errorMsg = data['detail'] ?? data['last_donation_date']?.first ?? 'Failed to update date';
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error. Please try again.'};
    }
  }

  /// Toggles emergency alerts snooze via PATCH /api/users/me/snooze/
  /// Supports custom duration: 1d, 3d, 7d, 30d, 90d (defaults to 30).
  Future<bool> setSnooze({required bool enable, int? days, UserProfile? fallbackUser}) async {
    final effectiveDays = enable ? (days ?? 30) : null;
    final pauseUntil = enable ? DateTime.now().add(Duration(days: effectiveDays!)).toIso8601String() : null;

    try {
      final token = await ApiClient().getAccessToken();
      if (token != null && token.isNotEmpty) {
        final payload = <String, dynamic>{
          'days': effectiveDays,
        };
        final response = await ApiClient().patch('users/me/snooze/', body: payload);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final serverPauseUntil = data['emergency_alerts_paused_until']?.toString() ??
              data['alert_pause_until']?.toString() ??
              pauseUntil;
          _applySnooze(serverPauseUntil, fallbackUser);
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) print('[setSnooze] API exception: $e');
    }

    // Graceful offline/local profile fallback
    _applySnooze(pauseUntil, fallbackUser);
    return true;
  }

  void _applySnooze(String? pauseUntil, UserProfile? fallbackUser) {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(alertPauseUntil: pauseUntil));
    } else {
      state = AsyncValue.data(ProfileModel(
        id: 0,
        username: fallbackUser?.primaryPhone ?? 'donor',
        firstName: fallbackUser?.fullName.split(' ').first ?? 'Donor',
        lastName: fallbackUser?.fullName.split(' ').skip(1).join(' ') ?? 'User',
        email: fallbackUser?.email ?? '',
        bloodGroup: fallbackUser?.bloodGroup ?? 'O+',
        district: fallbackUser?.categoryDetails['district'] ?? 'Dhaka',
        phoneNumber: fallbackUser?.primaryPhone ?? '',
        isVerified: true,
        isProfileComplete: true,
        alertPauseUntil: pauseUntil,
      ));
    }
  }

  /// Clears profile cache on logout or account switch
  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for Top Donors (5 columns on Profile screen)
final topDonorsProvider = FutureProvider<TopDonorsResponse>((ref) async {
  try {
    final res = await ApiClient().get('profile/top-donors/');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return TopDonorsResponse.fromJson(data);
    }
  } catch (e) {
    if (kDebugMode) print('[topDonorsProvider] error: $e');
  }
  return TopDonorsResponse(topDonors: [], otherDonorsCount: 0);
});

/// Provider for Global Leaderboard pagination
final globalRankProvider = FutureProvider.family<List<GlobalRankItem>, int>((ref, page) async {
  try {
    final res = await ApiClient().get('profile/global-rank/?page=$page');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results.map((e) => GlobalRankItem.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (e) {
    if (kDebugMode) print('[globalRankProvider] error: $e');
  }
  return [];
});

/// Provider for Profile Stories (Your Stories Tab)
final profileStoriesProvider = StateNotifierProvider<ProfileStoriesNotifier, AsyncValue<List<ProfileStoryModel>>>((ref) {
  return ProfileStoriesNotifier();
});

class ProfileStoriesNotifier extends StateNotifier<AsyncValue<List<ProfileStoryModel>>> {
  ProfileStoriesNotifier() : super(const AsyncValue.loading()) {
    fetchStories();
  }

  Future<void> fetchStories() async {
    try {
      final res = await ApiClient().get('profile/me/stories/');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['results'] as List<dynamic>? ?? [])
            .map((e) => ProfileStoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> addStory(String content) async {
    try {
      final res = await ApiClient().post(
        'posts/',
        body: {'content': content},
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        await fetchStories();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for Donation History Tab
final profileDonationsProvider = FutureProvider<List<DonationHistoryModel>>((ref) async {
  try {
    final res = await ApiClient().get('profile/me/donations/');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['results'] as List<dynamic>? ?? [])
          .map((e) => DonationHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    }
  } catch (e) {
    if (kDebugMode) print('[profileDonationsProvider] error: $e');
  }
  return [];
});

/// Provider for Activity Summary Tab
final profileActivityProvider = FutureProvider<List<ProfileActivityItem>>((ref) async {
  try {
    final res = await ApiClient().get('profile/me/activity/');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['results'] as List<dynamic>? ?? [])
          .map((e) => ProfileActivityItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    }
  } catch (e) {
    if (kDebugMode) print('[profileActivityProvider] error: $e');
  }
  return [];
});

/// Provider for Donor Ratings & Reviews (GET /api/profile/`<id>`/reviews/)
final donorReviewsProvider = FutureProvider.family<DonorReviewsResponse, int>((ref, donorId) async {
  try {
    final res = await ApiClient().get('profile/$donorId/reviews/');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return DonorReviewsResponse.fromJson(data);
    }
  } catch (e) {
    if (kDebugMode) print('[donorReviewsProvider] error: $e');
  }
  return DonorReviewsResponse(ratingAvg: 5.0, ratingCount: 0, reviews: []);
});


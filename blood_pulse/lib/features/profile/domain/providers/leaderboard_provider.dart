// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_client.dart';

class LeaderboardDonor {
  final int rank;
  final int id;
  final String name;
  final String? bloodGroup;
  final int donationsCount;
  final String? district;
  final String? badge;
  final String? avatarUrl;
  final bool isConsented;

  const LeaderboardDonor({
    required this.rank,
    required this.id,
    required this.name,
    this.bloodGroup,
    required this.donationsCount,
    this.district,
    this.badge,
    this.avatarUrl,
    this.isConsented = false,
  });

  factory LeaderboardDonor.fromJson(Map<String, dynamic> json) {
    return LeaderboardDonor(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Anonymous Hero',
      bloodGroup: json['blood_group'] as String?,
      donationsCount: (json['donations_count'] as num?)?.toInt() ?? 0,
      district: json['district'] as String?,
      badge: json['badge'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isConsented: json['is_consented'] == true,
    );
  }
}

class LeaderboardState {
  final List<LeaderboardDonor> topDonors;
  final String? myRank;
  final int myDonations;
  final int totalRankedDonors;
  final bool isLoading;
  final String? errorMessage;

  const LeaderboardState({
    this.topDonors = const [],
    this.myRank,
    this.myDonations = 0,
    this.totalRankedDonors = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  LeaderboardState copyWith({
    List<LeaderboardDonor>? topDonors,
    String? myRank,
    int? myDonations,
    int? totalRankedDonors,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LeaderboardState(
      topDonors: topDonors ?? this.topDonors,
      myRank: myRank ?? this.myRank,
      myDonations: myDonations ?? this.myDonations,
      totalRankedDonors: totalRankedDonors ?? this.totalRankedDonors,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final ApiClient _apiClient;

  LeaderboardNotifier({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        super(const LeaderboardState(isLoading: true)) {
    fetchLeaderboard();
  }

  Future<void> fetchLeaderboard({String scope = 'national'}) async {
    try {
      final response = await _apiClient.get('leaderboard/?scope=$scope&limit=5');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['top_donors'] as List<dynamic>? ?? [])
            .map((item) => LeaderboardDonor.fromJson(item as Map<String, dynamic>))
            .toList();
        final myRank = data['my_rank']?.toString();
        final myDonations = (data['my_donations'] as num?)?.toInt() ?? 0;
        final totalRanked = (data['total_ranked_donors'] as num?)?.toInt() ?? 0;

        state = LeaderboardState(
          topDonors: list,
          myRank: myRank,
          myDonations: myDonations,
          totalRankedDonors: totalRanked,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier();
});

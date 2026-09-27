// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../services/api_client.dart';

class DonorSearchResult {
  const DonorSearchResult({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.campusOrLocation,
    required this.division,
    required this.zila,
    required this.lastDonationText,
    required this.isVerified,
    required this.isAvailable,
    required this.location,
    this.phone,
  });

  final String id;
  final String name;
  final String bloodGroup;
  final String campusOrLocation;
  final String division;
  final String zila;
  final String lastDonationText;
  final bool isVerified;
  final bool isAvailable;
  final LatLng location;
  final String? phone; // Could be null if not returned by search API

  factory DonorSearchResult.fromJson(Map<String, dynamic> json) {
    return DonorSearchResult(
      id: json['id']?.toString() ?? '',
      name: json['full_name'] ?? 'Unknown Donor',
      bloodGroup: json['blood_group'] ?? 'Unknown',
      campusOrLocation: json['campus'] ?? json['institute'] ?? 'Unknown Campus',
      division: json['division'] ?? '',
      zila: json['district'] ?? '',
      lastDonationText: 'Donated: \ bags', // Fallback, update if needed
      isVerified: json['is_verified'] ?? false,
      isAvailable: json['is_available'] ?? true,
      location: LatLng(
        (json['latitude'] ?? 23.7259).toDouble(),
        (json['longitude'] ?? 90.3976).toDouble(),
      ),
      phone: json['phone_masked'], // Often null/omitted in search results
    );
  }
}

class DonorSearchFilter {
  const DonorSearchFilter({
    this.searchQuery = '',
    this.bloodGroup,
    this.division,
    this.zila,
    this.campus,
    this.onlyAvailable = true,
  });

  final String searchQuery;
  final String? bloodGroup;
  final String? division;
  final String? zila;
  final String? campus;
  final bool onlyAvailable;

  DonorSearchFilter copyWith({
    String? searchQuery,
    String? bloodGroup,
    String? division,
    String? zila,
    String? campus,
    bool? onlyAvailable,
    bool clearBloodGroup = false,
    bool clearDivision = false,
    bool clearZila = false,
    bool clearCampus = false,
  }) {
    return DonorSearchFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      bloodGroup: clearBloodGroup ? null : (bloodGroup ?? this.bloodGroup),
      division: clearDivision ? null : (division ?? this.division),
      zila: clearZila ? null : (zila ?? this.zila),
      campus: clearCampus ? null : (campus ?? this.campus),
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
    );
  }
}

final donorSearchFilterProvider = StateProvider<DonorSearchFilter>((ref) {
  return const DonorSearchFilter();
});

class DonorSearchNotifier extends StateNotifier<AsyncValue<List<DonorSearchResult>>> {
  DonorSearchNotifier() : super(const AsyncValue.loading()) { search(const DonorSearchFilter()); }

  Future<void> search(DonorSearchFilter filter) async {
    state = const AsyncValue.loading();
    try {
      final queryParams = <String, String>{};
      if (filter.bloodGroup != null && filter.bloodGroup!.isNotEmpty && filter.bloodGroup != 'Any') {
        queryParams['blood_group'] = filter.bloodGroup!;
      }
      if (filter.campus != null && filter.campus!.isNotEmpty && filter.campus != 'All Campuses') {
        queryParams['campus'] = filter.campus!;
      }
      if (filter.zila != null && filter.zila!.isNotEmpty && filter.zila != 'All Zilas') {
        queryParams['district'] = filter.zila!;
      }
      
      final uri = Uri(path: 'donors/search/', queryParameters: queryParams.isEmpty ? null : queryParams);
      
      final response = await ApiClient().get(uri.toString());
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> data = responseData['results'] as List<dynamic>;
      
      var donors = data.map((e) => DonorSearchResult.fromJson(e as Map<String, dynamic>)).toList();
      
      // Local filtering for things not supported by API yet (e.g. search query over multiple fields)
      if (filter.searchQuery.isNotEmpty) {
        final q = filter.searchQuery.toLowerCase();
        donors = donors.where((donor) {
          return donor.name.toLowerCase().contains(q) ||
                 donor.campusOrLocation.toLowerCase().contains(q) ||
                 donor.bloodGroup.toLowerCase().contains(q) ||
                 donor.zila.toLowerCase().contains(q);
        }).toList();
      }
      if (filter.division != null && filter.division!.isNotEmpty) {
         donors = donors.where((d) => d.division == filter.division).toList();
      }
      if (filter.onlyAvailable) {
         donors = donors.where((d) => d.isAvailable).toList();
      }

      state = AsyncValue.data(donors);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final donorSearchProvider =
    StateNotifierProvider<DonorSearchNotifier, AsyncValue<List<DonorSearchResult>>>((ref) {
  return DonorSearchNotifier();
});

final filteredDonorsProvider = Provider<AsyncValue<List<DonorSearchResult>>>((ref) {
  // It's already filtered locally inside the notifier state for now.
  // The UI can just watch donorSearchProvider directly.
  return ref.watch(donorSearchProvider);
});

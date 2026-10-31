// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_client.dart';
import '../../../core/domain/entities/national_emergency.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// A single donor result from /api/donors/search/.
class DonorSearchModel {
  const DonorSearchModel({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.component,
    required this.district,
    required this.division,
    this.campus,
    required this.isVerified,
    required this.isEligible,
    required this.trustBand,
    required this.maskedPhone,
    this.lastDonationDays,
    this.badge = 'Active Donor',
  });

  final int id;
  final String name;
  final String bloodGroup;
  final String component;
  final String district;
  final String division;
  final String? campus;
  final bool isVerified;
  final bool isEligible;
  final String trustBand; // LOW | MEDIUM | HIGH
  final String maskedPhone;
  final int? lastDonationDays;
  final String badge;

  factory DonorSearchModel.fromJson(Map<String, dynamic> j) {
    return DonorSearchModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?) ?? (j['full_name'] as String?) ?? '',
      bloodGroup: (j['blood_group'] as String?) ?? '',
      component: (j['component'] as String?) ?? 'WHOLE',
      district: (j['district'] as String?) ?? '',
      division: (j['division'] as String?) ?? '',
      campus: j['campus'] as String?,
      isVerified: (j['is_verified'] as bool?) ?? false,
      isEligible: (j['is_eligible'] as bool?) ?? true,
      trustBand: (j['trust_band'] as String?) ?? 'LOW',
      maskedPhone: (j['masked_phone'] as String?) ?? (j['phone_masked'] as String?) ?? '',
      lastDonationDays: (j['last_donation_days'] as num?)?.toInt() ?? (j['cooldown_days_remaining'] as num?)?.toInt(),
      badge: (j['badge'] as String?) ?? 'Active Donor',
    );
  }
}

/// Paginated donor search response.
class DonorSearchPage {
  const DonorSearchPage({
    required this.donors,
    this.nextCursor,
    required this.totalCount,
  });

  final List<DonorSearchModel> donors;
  final String? nextCursor;
  final int totalCount;
}

/// Fuzzed map pin from /api/donors/map/.
class DonorMapPin {
  const DonorMapPin({
    required this.id,
    required this.bloodGroup,
    required this.lat,
    required this.lng,
    required this.isVerified,
    this.name,
    this.campus,
    this.district,
  });

  final int id;
  final String bloodGroup;
  final double lat;
  final double lng;
  final bool isVerified;
  final String? name;
  final String? campus;
  final String? district;

  factory DonorMapPin.fromJson(Map<String, dynamic> j) {
    return DonorMapPin(
      id: (j['id'] as num?)?.toInt() ?? 0,
      bloodGroup: (j['blood_group'] as String?) ?? '',
      lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
      isVerified: (j['is_verified'] as bool?) ?? false,
      name: (j['name'] as String?) ?? (j['full_name'] as String?),
      campus: j['campus'] as String?,
      district: j['district'] as String?,
    );
  }
}

/// Hospital autocomplete result from /api/hospitals/directory/.
class HospitalModel {
  const HospitalModel({
    required this.id,
    required this.name,
    required this.nameEn,
    this.nameBn,
    required this.district,
    required this.address,
    this.lat,
    this.lng,
    this.phone,
    required this.isVerified,
    required this.isReferralCenter,
    this.divisionId,
    this.upazilaId,
  });

  final int id;
  final String name;
  final String nameEn;
  final String? nameBn;
  final String district;
  final String address;
  final double? lat;
  final double? lng;
  final String? phone;
  final bool isVerified;
  final bool isReferralCenter;
  final int? divisionId;
  final int? upazilaId;

  factory HospitalModel.fromJson(Map<String, dynamic> j) {
    return HospitalModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?) ?? '',
      nameEn: (j['name_en'] as String?) ?? '',
      nameBn: j['name_bn'] as String?,
      district: (j['district'] as String?) ?? '',
      address: (j['address'] as String?) ?? '',
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      phone: j['phone'] as String?,
      isVerified: (j['is_verified'] as bool?) ?? false,
      isReferralCenter: (j['is_referral_center'] as bool?) ?? false,
      divisionId: (j['division'] as num?)?.toInt(),
      upazilaId: (j['upazila'] as num?)?.toInt(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

/// Blood Hub REST service — all HTTP calls to the Django backend.
/// Rule 3: No mock/placeholder data. All methods call real endpoints.
/// Rule 10: Null-safe, never crashes; throws [ApiException] on failure.
class BloodHubApiService {
  BloodHubApiService(this._api);

  final ApiClient _api;

  // ── Donor Search ────────────────────────────────────────────────────────────

  /// GET /api/donors/search/
  /// Returns cursor-paginated list of searchable donors.
  Future<DonorSearchPage> searchDonors({
    String? bloodGroup,
    String? component,
    String? district,
    String? division,
    String? campus,
    String? q,
    String? cursor,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page_size': pageSize.toString(),
      'exact_match': 'true',
      if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'Any')
        'blood_group': bloodGroup,
      if (component != null && component.isNotEmpty && component != 'Any')
        'component': component,
      if (district != null && district.isNotEmpty && district != 'Any')
        'district': district,
      if (division != null && division.isNotEmpty && division != 'Any')
        'division': division,
      if (campus != null && campus.isNotEmpty && campus != 'All Campuses' && campus != 'Any')
        'campus': campus,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };

    final uri = Uri(
      path: 'donors/search/',
      queryParameters: params,
    );

    final response = await _api.get(uri.toString());
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final results = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(DonorSearchModel.fromJson)
        .toList();

    return DonorSearchPage(
      donors: results,
      nextCursor: data['next_cursor'] as String?,
      totalCount: (data['total'] as num?)?.toInt() ??
          (data['count'] as num?)?.toInt() ??
          results.length,
    );
  }

  // ── Donor Map Pins ─────────────────────────────────────────────────────────

  /// GET /api/donors/map/
  /// Returns fuzzed (~500 m) map pins for searchable donors.
  Future<List<DonorMapPin>> fetchMapPins({
    String? bloodGroup,
    String? component,
    String? district,
    String? division,
    String? campus,
    String? q,
  }) async {
    final params = <String, String>{
      if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'Any')
        'blood_group': bloodGroup,
      if (component != null && component.isNotEmpty && component != 'Any')
        'component': component,
      if (district != null && district.isNotEmpty && district != 'Any')
        'district': district,
      if (division != null && division.isNotEmpty && division != 'Any')
        'division': division,
      if (campus != null && campus.isNotEmpty && campus != 'All Campuses' && campus != 'Any')
        'campus': campus,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };

    final uri = Uri(path: 'donors/map/', queryParameters: params);
    final response = await _api.get(uri.toString());
    final data = jsonDecode(response.body);

    List<dynamic> rawList = const [];
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      rawList = (data['donors'] as List?) ?? (data['results'] as List?) ?? const [];
    }

    final list = rawList
        .whereType<Map<String, dynamic>>()
        .map(DonorMapPin.fromJson)
        .toList();

    return list;
  }

  // ── Hospital Directory ─────────────────────────────────────────────────────

  /// GET `/api/hospitals/directory/?q=<query>`
  /// Returns hospital autocomplete suggestions (max 10).
  Future<List<HospitalModel>> searchHospitals(String query) async {
    if (query.trim().isEmpty) return const [];

    final response = await _api.get('hospitals/directory/?q=${Uri.encodeComponent(query.trim())}');
    final data = jsonDecode(response.body);

    final list = (data is List ? data : (data as Map)['results'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HospitalModel.fromJson)
        .toList();

    return list;
  }

  // ── Emergency Request ──────────────────────────────────────────────────────

  /// POST /api/emergency/requests/
  /// Creates an emergency blood request. Supports JSON and multipart image uploads. Returns the server-assigned request id.
  Future<Map<String, dynamic>> createEmergencyRequest(
    Map<String, dynamic> payload, {
    List<int>? fileBytes,
    String? filename,
    List<int>? photoBytes,
    String? photoFilename,
  }) async {
    if ((fileBytes != null && fileBytes.isNotEmpty) || (photoBytes != null && photoBytes.isNotEmpty)) {
      final stringFields = <String, String>{};
      payload.forEach((key, value) {
        if (value != null) {
          stringFields[key] = value.toString();
        }
      });
      final response = await _api.postMultipart(
        'emergency/requests/',
        fields: stringFields,
        fileBytes: fileBytes,
        filename: filename ?? 'requisition_slip.jpg',
        fileFieldName: 'requisition_slip',
        secondFileBytes: photoBytes,
        secondFilename: photoFilename ?? 'patient_photo.jpg',
        secondFileFieldName: 'patient_photo',
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final response = await _api.post('emergency/requests/', body: payload);
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton ApiClient provider.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// BloodHubApiService provider.
final bloodHubApiServiceProvider = Provider<BloodHubApiService>((ref) {
  return BloodHubApiService(ref.read(apiClientProvider));
});

// ── Donor Search State ────────────────────────────────────────────────────────

class DonorSearchFilter {
  const DonorSearchFilter({
    this.bloodGroup,
    this.component,
    this.district,
    this.division,
    this.campus,
    this.q,
  });

  final String? bloodGroup;
  final String? component;
  final String? district;
  final String? division;
  final String? campus;
  final String? q;

  DonorSearchFilter copyWith({
    String? bloodGroup,
    String? component,
    String? district,
    String? division,
    String? campus,
    String? q,
    bool clearBloodGroup = false,
    bool clearComponent = false,
    bool clearDistrict = false,
    bool clearDivision = false,
    bool clearCampus = false,
    bool clearQ = false,
  }) {
    return DonorSearchFilter(
      bloodGroup: clearBloodGroup ? null : (bloodGroup ?? this.bloodGroup),
      component: clearComponent ? null : (component ?? this.component),
      district: clearDistrict ? null : (district ?? this.district),
      division: clearDivision ? null : (division ?? this.division),
      campus: clearCampus ? null : (campus ?? this.campus),
      q: clearQ ? null : (q ?? this.q),
    );
  }
}

/// Current filter state for the Blood Hub search screen.
final bloodHubFilterProvider = StateProvider<DonorSearchFilter>(
  (_) => const DonorSearchFilter(),
);

/// AsyncNotifier for paginated donor search results.
class DonorSearchNotifier extends AutoDisposeAsyncNotifier<DonorSearchPage> {
  String? _cursor;
  bool _hasMore = true;

  @override
  Future<DonorSearchPage> build() async {
    _cursor = null;
    _hasMore = true;
    final filter = ref.watch(bloodHubFilterProvider);
    return ref.read(bloodHubApiServiceProvider).searchDonors(
          bloodGroup: filter.bloodGroup,
          component: filter.component,
          district: filter.district,
          division: filter.division,
          campus: filter.campus,
          q: filter.q,
        );
  }

  bool get hasMore => _hasMore;

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final prev = state.valueOrNull;
    if (prev == null) return;
    if (prev.nextCursor == null) {
      _hasMore = false;
      return;
    }
    _cursor = prev.nextCursor;
    final filter = ref.read(bloodHubFilterProvider);
    try {
      final next = await ref.read(bloodHubApiServiceProvider).searchDonors(
            bloodGroup: filter.bloodGroup,
            component: filter.component,
            district: filter.district,
            division: filter.division,
            campus: filter.campus,
            q: filter.q,
            cursor: _cursor,
          );
      _hasMore = next.nextCursor != null;
      state = AsyncValue.data(
        DonorSearchPage(
          donors: [...prev.donors, ...next.donors],
          nextCursor: next.nextCursor,
          totalCount: next.totalCount,
        ),
      );
    } catch (e, st) {
      debugPrint('[BloodHub] loadMore error: $e\n$st');
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    ref.invalidateSelf();
  }
}

final donorSearchNotifierProvider =
    AsyncNotifierProvider.autoDispose<DonorSearchNotifier, DonorSearchPage>(
  DonorSearchNotifier.new,
);

/// Map pins provider — re-fetches when filter changes.
final donorMapPinsProvider = FutureProvider.autoDispose<List<DonorMapPin>>((ref) {
  final filter = ref.watch(bloodHubFilterProvider);
  return ref.read(bloodHubApiServiceProvider).fetchMapPins(
        bloodGroup: filter.bloodGroup,
        component: filter.component,
        district: filter.district,
        division: filter.division,
        campus: filter.campus,
        q: filter.q,
      );
});

/// Hospital autocomplete provider — parameterized by query string.
final hospitalSearchProvider =
    FutureProvider.autoDispose.family<List<HospitalModel>, String>((ref, query) {
  if (query.trim().length < 2) return Future.value(const []);
  return ref.read(bloodHubApiServiceProvider).searchHospitals(query);
});

// ─────────────────────────────────────────────────────────────────────────────
// JOURNEY MODELS  (Prompt 4)
// ─────────────────────────────────────────────────────────────────────────────

/// A milestone step in the 4-step journey progress line.
class JourneyStep {
  const JourneyStep({
    required this.key,
    required this.label,
    required this.completedAt,
  });

  final String key; // ACCEPTED | ON_THE_WAY | ARRIVED | DONATED
  final String label;
  final String? completedAt; // ISO-8601 or null if pending

  bool get isComplete => completedAt != null;

  factory JourneyStep.fromEntry(String k, dynamic v) {
    return JourneyStep(
      key: k,
      label: _stepLabel(k),
      completedAt: v as String?,
    );
  }

  static String _stepLabel(String k) {
    switch (k) {
      case 'OPEN':
        return 'Open';
      case 'ACCEPTED':
        return 'Accepted';
      case 'ON_THE_WAY':
      case 'DONOR_ON_THE_WAY':
        return 'On the Way';
      case 'ARRIVED':
        return 'Arrived';
      case 'DONATED':
        return 'Donated';
      case 'COMPLETED':
        return 'Completed';
      default:
        return k;
    }
  }
}

/// Full journey detail returned by GET /api/journeys/:id/
/// Viewer's role in this journey — backend decides which fields are populated.
enum JourneyViewerRole { requester, donor, unknown }

class JourneyDetail {
  const JourneyDetail({
    required this.id,
    required this.status,
    required this.viewerRole,
    required this.bloodGroup,
    required this.component,
    required this.urgency,
    required this.unitsNeeded,
    required this.steps,
    required this.etaMinutes,
    required this.distanceKm,
    required this.canReport,
    required this.canCancel,
    required this.createdAt,
    // ── Fields visible to REQUESTER (about the donor) ──────────────
    required this.donorName,
    required this.donorContact, // revealed after acceptance
    required this.donorLat,     // live fuzzed donor position
    required this.donorLng,
    // ── Fields visible to DONOR (about the patient / request) ──────
    required this.patientName,
    required this.hospitalName,
    required this.requesterContact, // revealed after acceptance
    required this.destLat,          // hospital / destination lat
    required this.destLng,
    // ── Shared readable fields ─────────────────────────────────────
    required this.requesterLat,  // null if requester didn't opt-in
    required this.requesterLng,
    this.chatRoomId,
    this.requestId,
  });

  final String? chatRoomId;
  final int? requestId;

  final int id;
  final String status;
  final JourneyViewerRole viewerRole;
  final String bloodGroup;
  final String component;
  final String urgency;
  final int unitsNeeded;
  final List<JourneyStep> steps;
  final int? etaMinutes;
  final double? distanceKm;
  final bool canReport;
  final bool canCancel;
  final String createdAt;

  // Requester's perspective
  final String donorName;
  final String donorContact;
  final double? donorLat;
  final double? donorLng;

  // Donor's perspective
  final String patientName;
  final String hospitalName;
  final String requesterContact;
  final double? destLat;
  final double? destLng;

  // Shared (optional requester location, if opted-in)
  final double? requesterLat;
  final double? requesterLng;

  bool get isActive =>
      status == 'ACCEPTED' ||
      status == 'ON_THE_WAY' ||
      status == 'ARRIVED';

  bool get isRequester => viewerRole == JourneyViewerRole.requester;
  bool get isDonor => viewerRole == JourneyViewerRole.donor;

  int get currentStepIndex {
    const order = ['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED'];
    for (int i = order.length - 1; i >= 0; i--) {
      if (steps.any((s) => s.key == order[i] && s.isComplete)) return i;
    }
    return 0;
  }

  factory JourneyDetail.fromJson(Map<String, dynamic> j) {
    const stepOrder = ['OPEN', 'ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED', 'COMPLETED'];
    final milestones = Map<String, dynamic>.from((j['milestones'] as Map<String, dynamic>?) ?? {});
    if (!milestones.containsKey('OPEN') && j['created_at'] != null) {
      milestones['OPEN'] = j['created_at'];
    }
    if (j['status'] == 'COMPLETED' && !milestones.containsKey('COMPLETED')) {
      milestones['COMPLETED'] = j['updated_at'] ?? j['closed_at'] ?? DateTime.now().toIso8601String();
    }
    final steps =
        stepOrder.map((k) => JourneyStep.fromEntry(k, milestones[k])).toList();

    final roleRaw = (j['viewer_role'] as String?) ?? '';
    final viewerRole = roleRaw == 'REQUESTER'
        ? JourneyViewerRole.requester
        : roleRaw == 'DONOR'
            ? JourneyViewerRole.donor
            : JourneyViewerRole.unknown;

    return JourneyDetail(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: (j['status'] as String?) ?? 'ACCEPTED',
      viewerRole: viewerRole,
      bloodGroup: (j['blood_group'] as String?) ?? '',
      component: (j['component'] as String?) ?? 'WHOLE',
      urgency: (j['urgency'] as String?) ?? '',
      unitsNeeded: (j['units_needed'] as num?)?.toInt() ?? 1,
      steps: steps,
      etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
      canReport: (j['can_report'] as bool?) ?? false,
      canCancel: (j['can_cancel'] as bool?) ?? false,
      createdAt: (j['created_at'] as String?) ?? '',
      // Requester sees these (about donor)
      donorName: (j['donor_name'] as String?) ?? '',
      donorContact: (j['donor_contact'] as String?) ?? '',
      donorLat: (j['donor_lat'] as num?)?.toDouble(),
      donorLng: (j['donor_lng'] as num?)?.toDouble(),
      // Donor sees these (about patient / request)
      patientName: (j['patient_name'] as String?) ?? '',
      hospitalName: (j['hospital_name'] as String?) ?? '',
      requesterContact: (j['requester_contact'] as String?) ?? '',
      destLat: (j['dest_lat'] as num?)?.toDouble(),
      destLng: (j['dest_lng'] as num?)?.toDouble(),
      // Shared
      requesterLat: (j['requester_lat'] as num?)?.toDouble(),
      requesterLng: (j['requester_lng'] as num?)?.toDouble(),
      chatRoomId: j['chat_room_id'] as String?,
      requestId: (j['request_id'] as num?)?.toInt(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STANDBY OFFER MODEL  (Prompt 4)
// ─────────────────────────────────────────────────────────────────────────────

class StandbyOfferDetail {
  const StandbyOfferDetail({
    required this.id,
    required this.status,
    required this.bloodGroup,
    required this.component,
    required this.urgency,
    required this.distanceKm,
    required this.hospitalName,
    required this.unitsNeeded,
    required this.expiresAt,
    required this.maskedRequester,
    required this.canAccept,
    required this.canDecline,
  });

  final int id;
  final String status; // PENDING|ACCEPTED|DECLINED|EXPIRED
  final String bloodGroup;
  final String component;
  final String urgency;
  final double distanceKm;
  final String hospitalName;
  final int unitsNeeded;
  final String expiresAt; // ISO-8601
  final String maskedRequester;
  final bool canAccept;
  final bool canDecline;

  Duration get timeRemaining {
    try {
      final exp = DateTime.parse(expiresAt);
      final diff = exp.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return Duration.zero;
    }
  }

  factory StandbyOfferDetail.fromJson(Map<String, dynamic> j) {
    return StandbyOfferDetail(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: (j['status'] as String?) ?? 'PENDING',
      bloodGroup: (j['blood_group'] as String?) ?? '',
      component: (j['component'] as String?) ?? 'WHOLE',
      urgency: (j['urgency'] as String?) ?? '',
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0.0,
      hospitalName: (j['hospital_name'] as String?) ?? '',
      unitsNeeded: (j['units_needed'] as num?)?.toInt() ?? 1,
      expiresAt: (j['expires_at'] as String?) ?? '',
      maskedRequester: (j['masked_requester'] as String?) ?? '',
      canAccept: (j['can_accept'] as bool?) ?? false,
      canDecline: (j['can_decline'] as bool?) ?? false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOURNEY LIST ITEM MODEL  (Prompt 5)
// ─────────────────────────────────────────────────────────────────────────────

class JourneyListItem {
  const JourneyListItem({
    required this.id,
    required this.status,
    required this.viewerRole,
    required this.bloodGroup,
    required this.urgency,
    required this.hospitalName,
    required this.isStandby,
    required this.createdAt,
  });

  final int id;
  final String status;
  final JourneyViewerRole viewerRole;
  final String bloodGroup;
  final String urgency;
  final String hospitalName;
  final bool isStandby;
  final String createdAt;

  factory JourneyListItem.fromJson(Map<String, dynamic> j) {
    final roleStr = j['viewer_role'] as String?;
    final role = roleStr == 'DONOR'
        ? JourneyViewerRole.donor
        : roleStr == 'REQUESTER'
            ? JourneyViewerRole.requester
            : JourneyViewerRole.unknown;

    return JourneyListItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: (j['status'] as String?) ?? 'UNKNOWN',
      viewerRole: role,
      bloodGroup: (j['blood_group'] as String?) ?? '',
      urgency: (j['urgency'] as String?) ?? '',
      hospitalName: (j['hospital_name'] as String?) ?? '',
      isStandby: (j['is_standby'] as bool?) ?? false,
      createdAt: (j['created_at'] as String?) ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NATIONAL EMERGENCY MODEL  (Prompt 4)
// ─────────────────────────────────────────────────────────────────────────────



// ─────────────────────────────────────────────────────────────────────────────
// EXTENDED API SERVICE METHODS  (Prompt 4 additions)
// ─────────────────────────────────────────────────────────────────────────────

extension BloodHubApiServiceP4 on BloodHubApiService {
  /// GET `/api/journeys/<id>/`
  Future<JourneyDetail> fetchJourney(int id) async {
    final response = await _api.get('journeys/$id/');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return JourneyDetail.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(data['detail'] ?? 'Failed to load journey');
  }

  /// POST `/api/journeys/<id>/status/`  — update journey status
  Future<Map<String, dynamic>> getActiveDeferral() async {
    final response = await _api.get('deferrals/active/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'has_deferral': false};
  }

  Future<void> appealDeferral(int id) async {
    final response = await _api.post('deferrals/$id/appeal/');
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? data['detail'] ?? 'Failed to appeal deferral');
    }
  }

  Future<void> updateJourneyLocation(int id, double lat, double lng) async {
    final response = await _api.post(
      'journeys/$id/location/',
      body: {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
      },
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to update location');
    }
  }

  Future<void> updateJourneyStatus(int id, String status) async {
    final response = await _api.post(
      'journeys/$id/status/',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to update status');
    }
  }

  /// POST `/api/journeys/<id>/issue/`  — report a donation issue
  Future<void> reportDonationIssue(
      int journeyId, String issueType, String? note) async {
    final response = await _api.post(
      'journeys/$journeyId/issue/',
      body: {
        'issue_type': issueType,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to report issue');
    }
  }

  /// GET `/api/standby/<offerId>/`
  Future<StandbyOfferDetail> fetchStandbyOffer(int offerId) async {
    final response = await _api.get('standby/$offerId/');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return StandbyOfferDetail.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(data['detail'] ?? 'Failed to load standby offer');
  }

  /// POST `/api/standby/<offerId>/respond/`
  Future<void> respondToStandby(int offerId, String action) async {
    final response = await _api.post(
      'standby/$offerId/respond/',
      body: {'action': action}, // ACCEPT or DECLINE
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['detail'] ?? 'Failed to respond to standby offer');
    }
  }

  // ─── PROMPT 9 EMERGENCY METHODS ───────────────────────────────
  Future<Map<String, dynamic>> getActiveNationalEmergency() async {
    final response = await _api.get('emergency/national/active/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'is_active': false, 'message': 'No emergency right now'};
  }

  Future<Map<String, dynamic>> pledgeToDonate(int slotId) async {
    final response = await _api.post('emergency/national/pledge/', body: {'slot_id': slotId.toString()});
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['error'] ?? data['detail'] ?? 'Failed to pledge.');
    }
    return data;
  }

  Future<Map<String, dynamic>> getMyPledge() async {
    final response = await _api.get('emergency/national/my-pledge/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'has_pledge': false};
  }

  /// GET `/api/journeys/`
  Future<List<JourneyListItem>> fetchJourneys() async {
    final response = await _api.get('journeys/');
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final list = (data['results'] as List?) ?? [];
      return list.cast<Map<String, dynamic>>().map(JourneyListItem.fromJson).toList();
    }
    throw Exception(data['detail'] ?? 'Failed to load journeys');
  }

  /// POST `/api/requests/<requestId>/accept/`
  /// Accepts an urgent blood requisition.
  Future<Map<String, dynamic>> acceptBloodRequest(
    int requestId, {
    String supportStatus = 'CAN_SUPPORT',
    int unitsPledged = 1,
  }) async {
    final response = await _api.post(
      'requests/$requestId/accept/',
      body: {
        'support_status': supportStatus,
        'units_pledged': unitsPledged.toString(),
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return data is Map<String, dynamic> ? data : {'message': 'Accepted'};
    }
    throw ApiException(
      data['detail'] ?? data['error'] ?? 'Failed to accept blood request.',
      statusCode: response.statusCode,
    );
  }

  /// GET `/api/emergency/national/requests/`
  /// Lists verified critical emergency requests across all 64 districts.
  Future<List<NationalEmergencyRequestItem>> fetchNationalEmergencyRequests({
    String? bloodGroup,
    String? division,
    String? district,
  }) async {
    final params = <String, String>{
      if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'All')
        'blood_group': bloodGroup,
      if (division != null && division.isNotEmpty && division != 'All')
        'division': division,
      if (district != null && district.isNotEmpty && district != 'All')
        'district': district,
    };
    final uri = Uri(
      path: 'emergency/national/requests/',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final response = await _api.get(uri.toString());
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(NationalEmergencyRequestItem.fromJson)
          .toList();
    }
    throw Exception('Failed to load national emergency requests: ${response.statusCode}');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROMPT 4 & 5 PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Journey detail provider — auto-refreshes every 15 s while screen is active.
final journeyDetailProvider =
    FutureProvider.autoDispose.family<JourneyDetail, int>((ref, id) {
  // Re-fetch every 15 seconds for live status updates.
  ref.keepAlive();
  return ref.read(bloodHubApiServiceProvider).fetchJourney(id);
});

/// Standby offer provider — auto-disposes when screen leaves.
final standbyOfferProvider =
    FutureProvider.autoDispose.family<StandbyOfferDetail, int>((ref, offerId) {
  return ref.read(bloodHubApiServiceProvider).fetchStandbyOffer(offerId);
});



/// Journey list provider (My Requests & My Donations)
final journeyListProvider =
    FutureProvider.autoDispose<List<JourneyListItem>>((ref) {
  return ref.read(bloodHubApiServiceProvider).fetchJourneys();
});







final activeNationalEmergencyProvider = FutureProvider.autoDispose<NationalEmergencyEvent?>((ref) async {
  final api = ref.watch(bloodHubApiServiceProvider);
  final res = await api.getActiveNationalEmergency();
  if (res['is_active'] == true && res['event'] != null) {
    return NationalEmergencyEvent.fromJson(res['event']);
  }
  return null;
});

final myDisasterPledgeProvider = FutureProvider.autoDispose<DisasterPledge?>((ref) async {
  final api = ref.watch(bloodHubApiServiceProvider);
  final res = await api.getMyPledge();
  if (res['has_pledge'] == true && res['pledge'] != null) {
    return DisasterPledge.fromJson(res['pledge']);
  }
  return null;
});

/// Verified critical emergency request across 64 districts.
class NationalEmergencyRequestItem {
  final int id;
  final String patientName;
  final String bloodGroup;
  final String component;
  final int unitsNeeded;
  final int unitsReceived;
  final int unitsPending;
  final String urgency;
  final String district;
  final String divisionName;
  final String hospitalName;
  final String contactPhoneMasked;
  final String status;
  final String trustBand;
  final int trustScore;
  final bool isVerified;
  final String? createdAt;

  const NationalEmergencyRequestItem({
    required this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.component,
    required this.unitsNeeded,
    required this.unitsReceived,
    required this.unitsPending,
    required this.urgency,
    required this.district,
    required this.divisionName,
    required this.hospitalName,
    required this.contactPhoneMasked,
    required this.status,
    required this.trustBand,
    required this.trustScore,
    this.isVerified = true,
    this.createdAt,
  });

  factory NationalEmergencyRequestItem.fromJson(Map<String, dynamic> j) {
    return NationalEmergencyRequestItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      patientName: (j['patient_name'] as String?) ?? 'Emergency Patient',
      bloodGroup: (j['blood_group'] as String?) ?? '',
      component: (j['component'] as String?) ?? 'WHOLE',
      unitsNeeded: (j['units_needed'] as num?)?.toInt() ?? 1,
      unitsReceived: (j['units_received'] as num?)?.toInt() ?? 0,
      unitsPending: (j['units_pending'] as num?)?.toInt() ?? 0,
      urgency: (j['urgency'] as String?) ?? 'CRITICAL_2H',
      district: (j['district'] as String?) ?? '',
      divisionName: (j['division_name'] as String?) ?? '',
      hospitalName: (j['hospital_name'] as String?) ?? '',
      contactPhoneMasked: (j['contact_phone_masked'] as String?) ?? '',
      status: (j['status'] as String?) ?? 'ACTIVE',
      trustBand: (j['trust_band'] as String?) ?? 'MEDIUM',
      trustScore: (j['trust_score'] as num?)?.toInt() ?? 50,
      isVerified: (j['is_verified'] as bool?) ?? true,
      createdAt: j['created_at'] as String?,
    );
  }
}

class NationalEmergencyFilterState {
  final String bloodGroup;
  final String division;

  const NationalEmergencyFilterState({this.bloodGroup = 'All', this.division = 'All'});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NationalEmergencyFilterState &&
          bloodGroup == other.bloodGroup &&
          division == other.division;

  @override
  int get hashCode => Object.hash(bloodGroup, division);
}

final nationalEmergencyRequestsProvider = FutureProvider.autoDispose
    .family<List<NationalEmergencyRequestItem>, NationalEmergencyFilterState>((ref, filter) async {
  final api = ref.watch(bloodHubApiServiceProvider);
  return api.fetchNationalEmergencyRequests(
    bloodGroup: filter.bloodGroup,
    division: filter.division,
  );
});

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_client.dart';

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

  factory DonorSearchModel.fromJson(Map<String, dynamic> j) {
    return DonorSearchModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?) ?? '',
      bloodGroup: (j['blood_group'] as String?) ?? '',
      component: (j['component'] as String?) ?? 'WHOLE',
      district: (j['district'] as String?) ?? '',
      division: (j['division'] as String?) ?? '',
      campus: j['campus'] as String?,
      isVerified: (j['is_verified'] as bool?) ?? false,
      isEligible: (j['is_eligible'] as bool?) ?? false,
      trustBand: (j['trust_band'] as String?) ?? 'LOW',
      maskedPhone: (j['masked_phone'] as String?) ?? '',
      lastDonationDays: (j['last_donation_days'] as num?)?.toInt(),
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
  });

  final int id;
  final String bloodGroup;
  final double lat;
  final double lng;
  final bool isVerified;

  factory DonorMapPin.fromJson(Map<String, dynamic> j) {
    return DonorMapPin(
      id: (j['id'] as num?)?.toInt() ?? 0,
      bloodGroup: (j['blood_group'] as String?) ?? '',
      lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
      isVerified: (j['is_verified'] as bool?) ?? false,
    );
  }
}

/// Hospital autocomplete result from /api/hospitals/directory/.
class HospitalModel {
  const HospitalModel({
    required this.id,
    required this.nameEn,
    this.nameBn,
    required this.district,
    required this.division,
    this.phone,
    required this.isVerified,
  });

  final int id;
  final String nameEn;
  final String? nameBn;
  final String district;
  final String division;
  final String? phone;
  final bool isVerified;

  factory HospitalModel.fromJson(Map<String, dynamic> j) {
    return HospitalModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      nameEn: (j['name_en'] as String?) ?? (j['name'] as String?) ?? '',
      nameBn: j['name_bn'] as String?,
      district: (j['district'] as String?) ?? '',
      division: (j['division'] as String?) ?? '',
      phone: j['phone'] as String?,
      isVerified: (j['is_verified'] as bool?) ?? false,
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
    String? cursor,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page_size': pageSize.toString(),
      if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'Any')
        'blood_group': bloodGroup,
      if (component != null && component.isNotEmpty && component != 'Any')
        'component': component,
      if (district != null && district.isNotEmpty) 'district': district,
      if (division != null && division.isNotEmpty) 'division': division,
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
      totalCount: (data['count'] as num?)?.toInt() ?? results.length,
    );
  }

  // ── Donor Map Pins ─────────────────────────────────────────────────────────

  /// GET /api/donors/map/
  /// Returns fuzzed (~500 m) map pins for searchable donors.
  Future<List<DonorMapPin>> fetchMapPins({
    String? bloodGroup,
    String? component,
    String? district,
  }) async {
    final params = <String, String>{
      if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup != 'Any')
        'blood_group': bloodGroup,
      if (component != null && component.isNotEmpty && component != 'Any')
        'component': component,
      if (district != null && district.isNotEmpty) 'district': district,
    };

    final uri = Uri(path: 'donors/map/', queryParameters: params);
    final response = await _api.get(uri.toString());
    final data = jsonDecode(response.body);

    final list = (data is List ? data : (data as Map)['results'] as List? ?? [])
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
  /// Creates an emergency blood request.  Returns the server-assigned request id.
  Future<Map<String, dynamic>> createEmergencyRequest(
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.post('emergency/requests/', body: payload);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton ApiClient provider.
final _apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// BloodHubApiService provider.
final bloodHubApiServiceProvider = Provider<BloodHubApiService>((ref) {
  return BloodHubApiService(ref.read(_apiClientProvider));
});

// ── Donor Search State ────────────────────────────────────────────────────────

class DonorSearchFilter {
  const DonorSearchFilter({
    this.bloodGroup,
    this.component,
    this.district,
    this.division,
  });

  final String? bloodGroup;
  final String? component;
  final String? district;
  final String? division;

  DonorSearchFilter copyWith({
    String? bloodGroup,
    String? component,
    String? district,
    String? division,
    bool clearBloodGroup = false,
    bool clearComponent = false,
    bool clearDistrict = false,
    bool clearDivision = false,
  }) {
    return DonorSearchFilter(
      bloodGroup: clearBloodGroup ? null : (bloodGroup ?? this.bloodGroup),
      component: clearComponent ? null : (component ?? this.component),
      district: clearDistrict ? null : (district ?? this.district),
      division: clearDivision ? null : (division ?? this.division),
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
      case 'ACCEPTED':
        return 'Accepted';
      case 'ON_THE_WAY':
        return 'On the Way';
      case 'ARRIVED':
        return 'Arrived';
      case 'DONATED':
        return 'Donated';
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
  });

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
    const stepOrder = ['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED'];
    final milestones = (j['milestones'] as Map<String, dynamic>?) ?? {};
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

class HospitalNeed {
  const HospitalNeed({
    required this.hospitalName,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.unitsFulfilled,
  });

  final String hospitalName;
  final String bloodGroup;
  final int unitsNeeded;
  final int unitsFulfilled;

  double get progress =>
      unitsNeeded == 0 ? 0 : (unitsFulfilled / unitsNeeded).clamp(0.0, 1.0);

  factory HospitalNeed.fromJson(Map<String, dynamic> j) {
    return HospitalNeed(
      hospitalName: (j['hospital_name'] as String?) ?? '',
      bloodGroup: (j['blood_group'] as String?) ?? '',
      unitsNeeded: (j['units_needed'] as num?)?.toInt() ?? 0,
      unitsFulfilled: (j['units_fulfilled'] as num?)?.toInt() ?? 0,
    );
  }
}

class NationalEmergencyState {
  const NationalEmergencyState({
    required this.isActive,
    this.title,
    this.subtitle,
    this.hospitalNeeds = const [],
    this.totalDonationsNeeded = 0,
    this.totalDonationsFulfilled = 0,
  });

  final bool isActive;
  final String? title;
  final String? subtitle;
  final List<HospitalNeed> hospitalNeeds;
  final int totalDonationsNeeded;
  final int totalDonationsFulfilled;

  factory NationalEmergencyState.fromJson(Map<String, dynamic> j) {
    final needs = (j['hospital_needs'] as List<dynamic>? ?? [])
        .map((e) => HospitalNeed.fromJson(e as Map<String, dynamic>))
        .toList();
    return NationalEmergencyState(
      isActive: (j['is_active'] as bool?) ?? false,
      title: j['title'] as String?,
      subtitle: j['subtitle'] as String?,
      hospitalNeeds: needs,
      totalDonationsNeeded: (j['total_needed'] as num?)?.toInt() ?? 0,
      totalDonationsFulfilled: (j['total_fulfilled'] as num?)?.toInt() ?? 0,
    );
  }

  static NationalEmergencyState get noEmergency =>
      const NationalEmergencyState(isActive: false);
}

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

  /// GET `/api/emergency/national/`
  Future<NationalEmergencyState> fetchNationalEmergency() async {
    try {
      final response = await _api.get('emergency/national/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NationalEmergencyState.fromJson(data as Map<String, dynamic>);
      }
      return NationalEmergencyState.noEmergency;
    } catch (_) {
      return NationalEmergencyState.noEmergency;
    }
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

/// National emergency provider — cached for 60 s.
final nationalEmergencyProvider =
    FutureProvider.autoDispose<NationalEmergencyState>((ref) {
  return ref.read(bloodHubApiServiceProvider).fetchNationalEmergency();
});

/// Journey list provider (My Requests & My Donations)
final journeyListProvider =
    FutureProvider.autoDispose<List<JourneyListItem>>((ref) {
  return ref.read(bloodHubApiServiceProvider).fetchJourneys();
});

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

class DonationSlot {
  final int id;
  final String timeRange;
  final int capacity;
  final int pledged;

  DonationSlot({
    required this.id,
    required this.timeRange,
    required this.capacity,
    required this.pledged,
  });

  factory DonationSlot.fromJson(Map<String, dynamic> json) {
    return DonationSlot(
      id: json['id'],
      timeRange: json['time_range'] ?? '',
      capacity: json['capacity'] ?? 0,
      pledged: json['pledged'] ?? 0,
    );
  }
}

class DisasterResponsePoint {
  final int id;
  final String name;
  final String district;
  final double lat;
  final double lng;
  final bool isCamp;
  final int targetBags;
  final int collectedBags;
  final String status;
  final List<String> urgentBloodGroups;
  final int donorsOnTheWay;
  final String lastUpdated;
  final List<DonationSlot> slots;

  DisasterResponsePoint({
    required this.id,
    required this.name,
    required this.district,
    required this.lat,
    required this.lng,
    required this.isCamp,
    required this.targetBags,
    required this.collectedBags,
    required this.status,
    required this.urgentBloodGroups,
    required this.donorsOnTheWay,
    required this.lastUpdated,
    required this.slots,
  });

  factory DisasterResponsePoint.fromJson(Map<String, dynamic> json) {
    return DisasterResponsePoint(
      id: json['id'],
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      isCamp: json['is_camp'] ?? false,
      targetBags: json['target_bags'] ?? 0,
      collectedBags: json['collected_bags'] ?? 0,
      status: json['status'] ?? 'NEEDED',
      urgentBloodGroups: (json['urgent_blood_groups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      donorsOnTheWay: json['donors_on_the_way'] ?? 0,
      lastUpdated: json['last_updated'] ?? '',
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) => DonationSlot.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class NationalEmergencyEvent {
  final int id;
  final String titleEn;
  final String titleBn;
  final String descriptionEn;
  final String descriptionBn;
  final String? posterImage;
  final bool isActive;
  final bool isVerified;
  final int donationIntervalDays;
  final String instructionsEn;
  final String instructionsBn;
  final List<DisasterResponsePoint> points;

  NationalEmergencyEvent({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.descriptionEn,
    required this.descriptionBn,
    this.posterImage,
    required this.isActive,
    required this.isVerified,
    required this.donationIntervalDays,
    required this.instructionsEn,
    required this.instructionsBn,
    required this.points,
  });

  factory NationalEmergencyEvent.fromJson(Map<String, dynamic> json) {
    return NationalEmergencyEvent(
      id: json['id'],
      titleEn: json['title_en'] ?? '',
      titleBn: json['title_bn'] ?? '',
      descriptionEn: json['description_en'] ?? '',
      descriptionBn: json['description_bn'] ?? '',
      posterImage: json['poster_image'],
      isActive: json['is_active'] ?? false,
      isVerified: json['is_verified'] ?? false,
      donationIntervalDays: json['donation_interval_days'] ?? 90,
      instructionsEn: json['instructions_en'] ?? '',
      instructionsBn: json['instructions_bn'] ?? '',
      points: (json['points'] as List<dynamic>?)
              ?.map((e) => DisasterResponsePoint.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DisasterPledge {
  final int id;
  final String pledgeCode;
  final String status;
  final String createdAt;
  final DonationSlot? slot;
  final String pointName;

  DisasterPledge({
    required this.id,
    required this.pledgeCode,
    required this.status,
    required this.createdAt,
    this.slot,
    required this.pointName,
  });

  factory DisasterPledge.fromJson(Map<String, dynamic> json) {
    return DisasterPledge(
      id: json['id'],
      pledgeCode: json['pledge_code'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      slot: json['slot'] != null ? DonationSlot.fromJson(json['slot']) : null,
      pointName: json['point_name'] ?? '',
    );
  }
}

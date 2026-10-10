// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import '../constants/app_config.dart';

/// UserModel representing user profile, verification status, and 90-day donation eligibility.
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phonePrimary,
    this.phoneSecondary,
    required this.role,
    this.institution,
    required this.division,
    required this.district,
    required this.upazila,
    required this.bloodGroup,
    this.adminLocked = true,
    this.lastDonationDate,
    this.profileImageUrl,
    this.badgeTier = 'Bronze',
    this.userIntent = 'DONATE_AND_REQUEST',
  });

  final String uid;
  final String name;
  final String email;
  final String phonePrimary;
  final String? phoneSecondary;
  final String role; // 'Student' or 'Civilian'
  final String? institution;
  final String division;
  final String district;
  final String upazila;
  final String bloodGroup;
  final bool adminLocked;
  final DateTime? lastDonationDate;
  final String? profileImageUrl;
  final String badgeTier; // 'Golden', 'Silver', 'Bronze'
  final String userIntent; // 'DONATE_AND_REQUEST' or 'ONLY_REQUEST'

  /// Returns false if user registered strictly to request blood
  bool get canDonate => userIntent != 'ONLY_REQUEST';

  /// Calculates whether the user is physiologically eligible to donate blood based on the cooldown rule.
  bool get isEligibleToDonate {
    if (userIntent == 'ONLY_REQUEST') return false;
    if (lastDonationDate == null) return true;
    final daysSinceDonation = DateTime.now().difference(lastDonationDate!).inDays;
    return daysSinceDonation >= AppConfig.donorCooldownDays;
  }

  /// Calculates exact number of days remaining in the cooldown interval. Returns 0 for ONLY_REQUEST users.
  int get cooldownDaysRemaining {
    if (userIntent == 'ONLY_REQUEST') return 0;
    if (lastDonationDate == null) return 0;
    final nextEligible = lastDonationDate!.add(const Duration(days: AppConfig.donorCooldownDays));
    final diff = nextEligible.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phonePrimary,
    String? phoneSecondary,
    String? role,
    String? institution,
    String? division,
    String? district,
    String? upazila,
    String? bloodGroup,
    bool? adminLocked,
    DateTime? lastDonationDate,
    String? profileImageUrl,
    String? badgeTier,
    String? userIntent,
  }) {
    return UserModel(
      uid:              uid ?? this.uid,
      name:             name ?? this.name,
      email:            email ?? this.email,
      phonePrimary:     phonePrimary ?? this.phonePrimary,
      phoneSecondary:   phoneSecondary ?? this.phoneSecondary,
      role:             role ?? this.role,
      institution:      institution ?? this.institution,
      division:         division ?? this.division,
      district:         district ?? this.district,
      upazila:          upazila ?? this.upazila,
      bloodGroup:       bloodGroup ?? this.bloodGroup,
      adminLocked:      adminLocked ?? this.adminLocked,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      profileImageUrl:  profileImageUrl ?? this.profileImageUrl,
      badgeTier:        badgeTier ?? this.badgeTier,
      userIntent:       userIntent ?? this.userIntent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phonePrimary': phonePrimary,
      'phoneSecondary': phoneSecondary,
      'role': role,
      'institution': institution,
      'division': division,
      'district': district,
      'upazila': upazila,
      'bloodGroup': bloodGroup,
      'adminLocked': adminLocked,
      'lastDonationDate': lastDonationDate?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'badgeTier': badgeTier,
      'user_intent': userIntent,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phonePrimary: map['phonePrimary'] as String,
      phoneSecondary: map['phoneSecondary'] as String?,
      role: map['role'] as String? ?? 'Civilian',
      institution: map['institution'] as String?,
      division: map['division'] as String? ?? 'Dhaka',
      district: map['district'] as String? ?? 'Dhaka',
      upazila: map['upazila'] as String? ?? 'Dhanmondi',
      bloodGroup: map['bloodGroup'] as String? ?? 'O+',
      adminLocked: map['adminLocked'] as bool? ?? true,
      lastDonationDate: map['lastDonationDate'] != null ? DateTime.parse(map['lastDonationDate'] as String) : null,
      profileImageUrl: map['profileImageUrl'] as String?,
      badgeTier: map['badgeTier'] as String? ?? 'Bronze',
      userIntent: map['user_intent'] as String? ?? map['userIntent'] as String? ?? 'DONATE_AND_REQUEST',
    );
  }
}

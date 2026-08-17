/// UserModel representing user profile, verification status, and 120-day donation eligibility.
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

  /// Calculates whether the user is physiologically eligible to donate blood based on the 120-day rule.
  bool get isEligibleToDonate {
    if (lastDonationDate == null) return true;
    final daysSinceDonation = DateTime.now().difference(lastDonationDate!).inDays;
    return daysSinceDonation >= 120;
  }

  /// Calculates exact number of days remaining in the 120-day cooldown interval.
  int get cooldownDaysRemaining {
    if (lastDonationDate == null) return 0;
    final nextEligible = lastDonationDate!.add(const Duration(days: 120));
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
    );
  }
}

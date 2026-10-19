// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

class ProfileModel {
  final int id;
  final int? userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? bloodGroup;
  final String? district;
  final String? upazila;
  final int? upazilaId;
  final String? phoneNumber;
  final String? lastDonationDate;
  final bool isVerified;
  final bool isProfileComplete;
  final List<String> missingFields;
  final String? bio;
  final int? weightKg;
  final bool showInRankings;
  final String? institute;
  final String? address;
  final int totalBagsDonated;
  final int bagsDonated; // Verified bags only
  final String? profilePicture;
  final int rank;
  final int globalRank;
  final String badge;
  final String? donorTitle;
  final String? occupation;
  final String? positionDisplay;
  final String? alertPauseUntil;
  final bool showContact;
  final bool publicProfile;
  final bool notificationsEnabled;
  final bool emergencyAlertsEnabled;
  final String? nextEligibleDate;
  final int daysLeft;
  final bool isEligible;
  final double ratingAvg;
  final int ratingCount;
  final int xp;
  final int level;
  final double levelProgress;
  final int nextLevelXp;
  final String userIntent;
  final bool isAvailable;
  final List<DonationHistoryModel> donationHistory;
  final List<RecentLogModel> recentLogs;

  static const Object _sentinel = Object();

  ProfileModel({
    required this.id,
    this.userId,
    this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.bloodGroup,
    this.district,
    this.upazila,
    this.upazilaId,
    this.phoneNumber,
    this.lastDonationDate,
    this.isVerified = false,
    this.isProfileComplete = false,
    this.missingFields = const [],
    this.bio,
    this.weightKg,
    this.showInRankings = true,
    this.institute,
    this.address,
    this.totalBagsDonated = 0,
    this.bagsDonated = 0,
    this.profilePicture,
    this.rank = 0,
    this.globalRank = 0,
    this.badge = 'Active Donor',
    this.donorTitle,
    this.occupation,
    this.positionDisplay,
    this.alertPauseUntil,
    this.showContact = false,
    this.publicProfile = false,
    this.notificationsEnabled = true,
    this.emergencyAlertsEnabled = true,
    this.nextEligibleDate,
    this.daysLeft = 0,
    this.isEligible = true,
    this.ratingAvg = 5.0,
    this.ratingCount = 0,
    this.xp = 0,
    this.level = 1,
    this.levelProgress = 0.0,
    this.nextLevelXp = 100,
    this.userIntent = 'DONATE_AND_REQUEST',
    this.isAvailable = true,
    this.donationHistory = const [],
    this.recentLogs = const [],
  });

  ProfileModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
    String? email,
    String? bloodGroup,
    String? district,
    String? upazila,
    int? upazilaId,
    String? phoneNumber,
    String? lastDonationDate,
    bool? isVerified,
    bool? isProfileComplete,
    List<String>? missingFields,
    String? bio,
    int? weightKg,
    bool? showInRankings,
    String? institute,
    String? address,
    int? totalBagsDonated,
    int? bagsDonated,
    String? profilePicture,
    int? rank,
    int? globalRank,
    String? badge,
    String? donorTitle,
    String? occupation,
    String? positionDisplay,
    Object? alertPauseUntil = _sentinel,
    bool clearAlertPauseUntil = false,
    bool? showContact,
    bool? publicProfile,
    bool? notificationsEnabled,
    bool? emergencyAlertsEnabled,
    String? nextEligibleDate,
    int? daysLeft,
    bool? isEligible,
    double? ratingAvg,
    int? ratingCount,
    int? xp,
    int? level,
    double? levelProgress,
    int? nextLevelXp,
    String? userIntent,
    bool? isAvailable,
    List<DonationHistoryModel>? donationHistory,
    List<RecentLogModel>? recentLogs,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      district: district ?? this.district,
      upazila: upazila ?? this.upazila,
      upazilaId: upazilaId ?? this.upazilaId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      isVerified: isVerified ?? this.isVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      missingFields: missingFields ?? this.missingFields,
      bio: bio ?? this.bio,
      weightKg: weightKg ?? this.weightKg,
      showInRankings: showInRankings ?? this.showInRankings,
      institute: institute ?? this.institute,
      address: address ?? this.address,
      totalBagsDonated: totalBagsDonated ?? this.totalBagsDonated,
      bagsDonated: bagsDonated ?? this.bagsDonated,
      profilePicture: profilePicture ?? this.profilePicture,
      rank: rank ?? this.rank,
      globalRank: globalRank ?? this.globalRank,
      badge: badge ?? this.badge,
      donorTitle: donorTitle ?? this.donorTitle,
      occupation: occupation ?? this.occupation,
      positionDisplay: positionDisplay ?? this.positionDisplay,
      alertPauseUntil: clearAlertPauseUntil
          ? null
          : (identical(alertPauseUntil, _sentinel)
              ? this.alertPauseUntil
              : alertPauseUntil as String?),
      showContact: showContact ?? this.showContact,
      publicProfile: publicProfile ?? this.publicProfile,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emergencyAlertsEnabled: emergencyAlertsEnabled ?? this.emergencyAlertsEnabled,
      nextEligibleDate: nextEligibleDate ?? this.nextEligibleDate,
      daysLeft: daysLeft ?? this.daysLeft,
      isEligible: isEligible ?? this.isEligible,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      levelProgress: levelProgress ?? this.levelProgress,
      nextLevelXp: nextLevelXp ?? this.nextLevelXp,
      userIntent: userIntent ?? this.userIntent,
      isAvailable: isAvailable ?? this.isAvailable,
      donationHistory: donationHistory ?? this.donationHistory,
      recentLogs: recentLogs ?? this.recentLogs,
    );
  }

  bool get isSnoozed {
    if (alertPauseUntil == null || alertPauseUntil!.isEmpty) return false;
    final parsed = DateTime.tryParse(alertPauseUntil!);
    if (parsed == null) return false;
    return parsed.isAfter(DateTime.now());
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? '').toString().trim();
    String? fName = json['first_name'];
    String? lName = json['last_name'];
    if ((fName == null || fName.isEmpty) && rawName.isNotEmpty) {
      final parts = rawName.split(' ');
      fName = parts.first;
      lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final totalBags = (json['total_bags_donated'] as num?)?.toInt() ??
        (json['bags_donated'] as num?)?.toInt() ??
        0;
    final verifiedBags = (json['bags_donated'] as num?)?.toInt() ??
        (json['verified_bags'] as num?)?.toInt() ??
        totalBags;

    final rankVal = (json['rank'] as num?)?.toInt() ??
        (json['global_rank'] as num?)?.toInt() ??
        0;

    return ProfileModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt(),
      username: json['username'],
      firstName: fName,
      lastName: lName,
      email: json['email'],
      bloodGroup: json['blood_group'],
      district: json['district'],
      upazila: json['upazila'],
      upazilaId: (json['upazila_id'] as num?)?.toInt(),
      phoneNumber: json['phone_number'],
      lastDonationDate: json['last_donation_date'] ?? json['last_donation'],
      isVerified: json['is_verified'] ?? (verifiedBags > 0),
      isProfileComplete: json['is_profile_complete'] ?? true,
      missingFields: (json['missing_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      bio: json['bio'],
      weightKg: (json['weight_kg'] as num?)?.toInt(),
      showInRankings: json['show_in_rankings'] ?? true,
      institute: json['institute'],
      address: json['address'],
      totalBagsDonated: totalBags,
      bagsDonated: verifiedBags,
      profilePicture: json['photo'] ?? json['profile_picture'],
      rank: rankVal,
      globalRank: rankVal,
      badge: json['tier'] ?? json['badge'] ?? 'Active Donor',
      donorTitle: json['donor_title'],
      occupation: json['occupation'],
      positionDisplay: json['position_display'],
      alertPauseUntil: json['emergency_alerts_paused_until']?.toString() ?? json['alert_pause_until']?.toString() ?? json['deferral_until']?.toString(),
      showContact: json['show_contact'] ?? false,
      publicProfile: json['public_profile'] ?? false,
      notificationsEnabled: json['notifications_enabled'] ?? true,
      emergencyAlertsEnabled: json['emergency_alerts_enabled'] ?? true,
      nextEligibleDate: json['next_eligible_date']?.toString(),
      daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
      isEligible: json['is_eligible'] ?? true,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      levelProgress: (json['level_progress'] as num?)?.toDouble() ?? 0.0,
      nextLevelXp: (json['next_level_xp'] as num?)?.toInt() ?? 100,
      userIntent: json['user_intent'] ?? 'DONATE_AND_REQUEST',
      isAvailable: json['is_available'] ?? true,
      donationHistory: (json['donation_history'] as List<dynamic>?)
              ?.map((e) => DonationHistoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentLogs: (json['recent_logs'] as List<dynamic>?)
              ?.map((e) => RecentLogModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get fullName {
    if (firstName != null && firstName!.isNotEmpty) {
      return '$firstName ${lastName ?? ''}'.trim();
    }
    return username ?? 'Anonymous Donor';
  }

  String get tier => badge;
}

class DonationHistoryModel {
  final int id;
  final String date;
  final String hospital;
  final String city;
  final int bags;
  final int? volumeMl;
  final String donationType;
  final String how;
  final String source;
  final bool verified;
  final String? notes;

  DonationHistoryModel({
    required this.id,
    required this.date,
    required this.hospital,
    this.city = '',
    this.bags = 1,
    this.volumeMl,
    this.donationType = 'whole_blood',
    this.how = 'voluntary',
    this.source = 'self_reported',
    this.verified = false,
    this.notes,
  });

  String get location => hospital;
  int get bagsDonated => bags;

  factory DonationHistoryModel.fromJson(Map<String, dynamic> json) {
    final hosp = (json['hospital'] ?? json['location'] ?? 'Medical Center').toString();
    final dDate = (json['donated_at'] ?? json['date'] ?? '').toString();
    final bCount = (json['bags'] as num?)?.toInt() ?? (json['bags_donated'] as num?)?.toInt() ?? 1;
    final isVer = json['verified'] == true || json['source'] == 'verified';

    return DonationHistoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: dDate,
      hospital: hosp,
      city: (json['city'] ?? '').toString(),
      bags: bCount,
      volumeMl: (json['volume_ml'] as num?)?.toInt(),
      donationType: (json['donation_type'] ?? 'whole_blood').toString(),
      how: (json['how'] ?? 'voluntary').toString(),
      source: (json['source'] ?? (isVer ? 'verified' : 'self_reported')).toString(),
      verified: isVer,
      notes: json['notes']?.toString(),
    );
  }
}

class RecentLogModel {
  final int id;
  final String logType;
  final String title;
  final String description;
  final String timestamp;
  final bool isSuccess;

  RecentLogModel({
    required this.id,
    required this.logType,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.isSuccess,
  });

  factory RecentLogModel.fromJson(Map<String, dynamic> json) {
    return RecentLogModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      logType: json['log_type'] ?? 'SYSTEM',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      timestamp: json['timestamp'] ?? '',
      isSuccess: json['is_success'] ?? true,
    );
  }
}

class TopDonorItem {
  final int id;
  final String name;
  final String? photo;
  final int rank;
  final int verifiedBags;
  final String bloodGroup;
  final bool isCurrentUser;

  TopDonorItem({
    required this.id,
    required this.name,
    this.photo,
    required this.rank,
    required this.verifiedBags,
    required this.bloodGroup,
    this.isCurrentUser = false,
  });

  factory TopDonorItem.fromJson(Map<String, dynamic> json) {
    return TopDonorItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Donor').toString(),
      photo: json['photo']?.toString(),
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      verifiedBags: (json['verified_bags'] as num?)?.toInt() ?? 0,
      bloodGroup: (json['blood_group'] ?? 'O+').toString(),
      isCurrentUser: json['is_current_user'] == true,
    );
  }

  int get bags => verifiedBags;
}

class TopDonorsResponse {
  final List<TopDonorItem> topDonors;
  final int otherDonorsCount;

  TopDonorsResponse({
    required this.topDonors,
    this.otherDonorsCount = 0,
  });

  factory TopDonorsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['top_donors'] as List<dynamic>? ?? [])
        .map((e) => TopDonorItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return TopDonorsResponse(
      topDonors: list,
      otherDonorsCount: (json['other_donors_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class GlobalRankItem {
  final int rank;
  final int id;
  final String name;
  final String? photo;
  final String bloodGroup;
  final int verifiedBags;
  final String tier;
  final double ratingAvg;
  final int ratingCount;
  final bool isCaller;

  GlobalRankItem({
    required this.rank,
    required this.id,
    required this.name,
    this.photo,
    required this.bloodGroup,
    required this.verifiedBags,
    required this.tier,
    required this.ratingAvg,
    required this.ratingCount,
    this.isCaller = false,
  });

  factory GlobalRankItem.fromJson(Map<String, dynamic> json) {
    return GlobalRankItem(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Donor').toString(),
      photo: json['photo']?.toString(),
      bloodGroup: (json['blood_group'] ?? 'O+').toString(),
      verifiedBags: (json['verified_bags'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] ?? 'Active Donor').toString(),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isCaller: json['is_caller'] == true,
    );
  }
}

class BloodGroupChangeRequestModel {
  final int id;
  final String currentGroup;
  final String requestedGroup;
  final String reason;
  final String labName;
  final String testDate;
  final String status; // 'pending', 'under_review', 'approved', 'rejected'
  final String? notes;
  final String? createdAt;

  BloodGroupChangeRequestModel({
    required this.id,
    required this.currentGroup,
    required this.requestedGroup,
    required this.reason,
    required this.labName,
    required this.testDate,
    required this.status,
    this.notes,
    this.createdAt,
  });

  factory BloodGroupChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return BloodGroupChangeRequestModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      currentGroup: (json['current_group'] ?? '').toString(),
      requestedGroup: (json['requested_group'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      labName: (json['lab_name'] ?? '').toString(),
      testDate: (json['test_date'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ProfileStoryModel {
  final int id;
  final String authorName;
  final String? authorPhoto;
  final String? location;
  final String content;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final String createdAt;

  ProfileStoryModel({
    required this.id,
    required this.authorName,
    this.authorPhoto,
    this.location,
    required this.content,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
  });

  factory ProfileStoryModel.fromJson(Map<String, dynamic> json) {
    return ProfileStoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      authorName: (json['author_name'] ?? 'Donor').toString(),
      authorPhoto: json['author_photo']?.toString(),
      location: json['location']?.toString(),
      content: (json['content'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? (json['reactions_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  String get timeAgo {
    try {
      final dt = DateTime.tryParse(createdAt);
      if (dt == null) return createdAt;
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return createdAt;
    }
  }
}

class ProfileActivityItem {
  final int id;
  final String title;
  final String subtitle;
  final String timestamp;
  final String status;
  final bool autoVerified;

  ProfileActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.status,
    this.autoVerified = false,
  });

  factory ProfileActivityItem.fromJson(Map<String, dynamic> json) {
    return ProfileActivityItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      autoVerified: json['auto_verified'] == true,
    );
  }

  String get description => subtitle;

  String get timeAgo {
    try {
      final dt = DateTime.tryParse(timestamp);
      if (dt == null) return timestamp;
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return timestamp;
    }
  }
}

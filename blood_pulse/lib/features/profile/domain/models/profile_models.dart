class ProfileModel {
  final int id;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? bloodGroup;
  final String? district;
  final String? phoneNumber;
  final String? lastDonationDate;
  final bool isVerified;
  final bool isProfileComplete;
  final String? bio;
  final String? institute;
  final String? address;
  final int totalBagsDonated;
  final String? profilePicture;
  final int globalRank;
  final String badge;
  final List<DonationHistoryModel> donationHistory;
  final List<RecentLogModel> recentLogs;

  ProfileModel({
    required this.id,
    this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.bloodGroup,
    this.district,
    this.phoneNumber,
    this.lastDonationDate,
    this.isVerified = false,
    this.isProfileComplete = false,
    this.bio,
    this.institute,
    this.address,
    this.totalBagsDonated = 0,
    this.profilePicture,
    this.globalRank = 0,
    this.badge = 'Green Donor',
    this.donationHistory = const [],
    this.recentLogs = const [],
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      bloodGroup: json['blood_group'],
      district: json['district'],
      phoneNumber: json['phone_number'],
      lastDonationDate: json['last_donation_date'],
      isVerified: json['is_verified'] ?? false,
      isProfileComplete: json['is_profile_complete'] ?? false,
      bio: json['bio'],
      institute: json['institute'],
      address: json['address'],
      totalBagsDonated: json['total_bags_donated'] ?? 0,
      profilePicture: json['profile_picture'],
      globalRank: json['global_rank'] ?? 0,
      badge: json['badge'] ?? 'Green Donor',
      donationHistory: (json['donation_history'] as List<dynamic>?)
              ?.map((e) => DonationHistoryModel.fromJson(e))
              .toList() ??
          [],
      recentLogs: (json['recent_logs'] as List<dynamic>?)
              ?.map((e) => RecentLogModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  String get fullName {
    if (firstName != null && firstName!.isNotEmpty) {
      return '$firstName ${lastName ?? ''}'.trim();
    }
    return username ?? 'Anonymous User';
  }
}

class DonationHistoryModel {
  final int id;
  final String date;
  final String location;
  final int bagsDonated;
  final String? notes;

  DonationHistoryModel({
    required this.id,
    required this.date,
    required this.location,
    required this.bagsDonated,
    this.notes,
  });

  factory DonationHistoryModel.fromJson(Map<String, dynamic> json) {
    return DonationHistoryModel(
      id: json['id'],
      date: json['date'],
      location: json['location'],
      bagsDonated: json['bags_donated'] ?? 1,
      notes: json['notes'],
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
      id: json['id'],
      logType: json['log_type'] ?? 'SYSTEM',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      timestamp: json['timestamp'] ?? '',
      isSuccess: json['is_success'] ?? true,
    );
  }
}

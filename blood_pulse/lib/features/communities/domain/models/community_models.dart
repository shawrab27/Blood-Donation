// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

class Division {
  final int id;
  final String name;
  
  Division({required this.id, required this.name});
  
  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(id: json['id'] as int, name: json['name'] as String);
  }
}

class District {
  final int id;
  final String name;
  final int divisionId;
  final String divisionName;

  District({required this.id, required this.name, required this.divisionId, required this.divisionName});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as int,
      name: json['name'] as String,
      divisionId: json['division'] as int,
      divisionName: (json['division_name'] as String?) ?? '',
    );
  }
}

class Upazila {
  final int id;
  final String name;
  final int districtId;
  final String districtName;

  Upazila({required this.id, required this.name, required this.districtId, required this.districtName});

  factory Upazila.fromJson(Map<String, dynamic> json) {
    return Upazila(
      id: json['id'] as int,
      name: json['name'] as String,
      districtId: json['district'] as int,
      districtName: (json['district_name'] as String?) ?? '',
    );
  }
}

class NationalCommunity {
  final int id;
  final String name;
  final String description;
  final String activeDonors;
  final String? logoUrl;
  final String phoneNumber;

  NationalCommunity({
    required this.id,
    required this.name,
    required this.description,
    required this.activeDonors,
    this.logoUrl,
    this.phoneNumber = '',
  });

  factory NationalCommunity.fromJson(Map<String, dynamic> json) {
    return NationalCommunity(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      activeDonors: json['active_donors'] as String,
      logoUrl: json['logo'] as String?,
      phoneNumber: json['phone_number'] as String? ?? '',
    );
  }
}

class MedicalPartner {
  final int id;
  final String name;
  final String location;
  final String accreditation;
  final String? imageUrl;
  final Map<String, dynamic> stockStatus;

  MedicalPartner({
    required this.id,
    required this.name,
    required this.location,
    required this.accreditation,
    this.imageUrl,
    required this.stockStatus,
  });

  factory MedicalPartner.fromJson(Map<String, dynamic> json) {
    return MedicalPartner(
      id: json['id'] as int,
      name: json['name'] as String,
      location: json['location'] as String,
      accreditation: json['accreditation'] as String,
      imageUrl: json['image'] as String?,
      stockStatus: json['stock_status'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ExecutiveMember {
  final int id;
  final int clubId;
  final String name;
  final String designation;
  final String phoneNumber;
  final String? photoUrl;

  ExecutiveMember({
    required this.id,
    required this.clubId,
    required this.name,
    required this.designation,
    required this.phoneNumber,
    this.photoUrl,
  });

  factory ExecutiveMember.fromJson(Map<String, dynamic> json) {
    return ExecutiveMember(
      id: json['id'] as int,
      clubId: json['club'] as int,
      name: json['name'] as String,
      designation: json['designation'] as String,
      phoneNumber: json['phone_number'] as String,
      photoUrl: json['photo'] as String?,
    );
  }
}

class LocalClub {
  final int id;
  final String name;
  final int? establishedYear;
  final String slogan;
  final String description;
  final int? divisionId;
  final String divisionName;
  final int? districtId;
  final String districtName;
  final int? upazilaId;
  final String upazilaName;
  final String? coverPhotoUrl;
  final String presidentName;
  final String contactNumber;
  final String? presidentPhotoUrl;
  final String totalDonors;
  final String activeDonors;
  final String contributions;
  final bool isVerified;
  final List<ExecutiveMember> executiveMembers;

  LocalClub({
    required this.id,
    required this.name,
    this.establishedYear,
    required this.slogan,
    required this.description,
    this.divisionId,
    required this.divisionName,
    this.districtId,
    required this.districtName,
    this.upazilaId,
    required this.upazilaName,
    this.coverPhotoUrl,
    required this.presidentName,
    required this.contactNumber,
    this.presidentPhotoUrl,
    required this.totalDonors,
    required this.activeDonors,
    required this.contributions,
    required this.isVerified,
    required this.executiveMembers,
  });

  factory LocalClub.fromJson(Map<String, dynamic> json) {
    var execMembersList = json['executive_members'] as List<dynamic>? ?? [];
    List<ExecutiveMember> execMembers = execMembersList.map((e) => ExecutiveMember.fromJson(e)).toList();

    return LocalClub(
      id: json['id'] as int,
      name: json['name'] as String,
      establishedYear: json['established_year'] as int?,
      slogan: json['slogan'] as String? ?? '',
      description: json['description'] as String,
      divisionId: json['division'] as int?,
      divisionName: json['division_name'] as String? ?? '',
      districtId: json['district'] as int?,
      districtName: json['district_name'] as String? ?? '',
      upazilaId: json['upazila'] as int?,
      upazilaName: json['upazila_name'] as String? ?? '',
      coverPhotoUrl: json['cover_photo'] as String?,
      presidentName: json['president_name'] as String,
      contactNumber: json['contact_number'] as String,
      presidentPhotoUrl: json['president_photo'] as String?,
      totalDonors: json['total_donors'] as String,
      activeDonors: json['active_donors'] as String,
      contributions: json['contributions'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      executiveMembers: execMembers,
    );
  }

  static final List<LocalClub> fallbackClubs = [
    LocalClub(
      id: 1,
      name: 'Uttara Blood Warriors',
      establishedYear: 2015,
      slogan: 'You give today, they live today',
      description:
          'Dedicated to saving lives in Uttara since 2015, the Uttara Blood Warriors is a community-driven network of altruistic donors focused on ensuring a safe and reliable blood supply.',
      divisionId: 1,
      divisionName: 'Dhaka',
      districtId: 1,
      districtName: 'Dhaka',
      upazilaId: 1,
      upazilaName: 'Uttara',
      presidentName: 'Dr. Rafiqul Islam',
      contactNumber: '+880 1711-234567',
      totalDonors: '1.2k+',
      activeDonors: '850+',
      contributions: '5k+',
      isVerified: true,
      executiveMembers: [
        ExecutiveMember(
          id: 1,
          clubId: 1,
          name: 'Tanvir Hossain',
          designation: 'General Secretary',
          phoneNumber: '+880 1712-345678',
        ),
        ExecutiveMember(
          id: 2,
          clubId: 1,
          name: 'Nusrat Jahan',
          designation: 'Organizing Secretary',
          phoneNumber: '+880 1713-456789',
        ),
      ],
    ),
    LocalClub(
      id: 2,
      name: 'Dhanmondi Voluntary Blood Network',
      establishedYear: 2018,
      slogan: 'Together for humanity',
      description:
          'A neighborhood-focused youth blood donation circle connecting Dhanmondi donors directly with nearby medical centers in Dhaka.',
      divisionId: 1,
      divisionName: 'Dhaka',
      districtId: 1,
      districtName: 'Dhaka',
      upazilaId: 2,
      upazilaName: 'Dhanmondi',
      presidentName: 'Engr. Mahmudul Hasan',
      contactNumber: '+880 1714-567890',
      totalDonors: '800+',
      activeDonors: '420+',
      contributions: '2.4k+',
      isVerified: true,
      executiveMembers: [
        ExecutiveMember(
          id: 3,
          clubId: 2,
          name: 'Sadia Afroz',
          designation: 'Vice President',
          phoneNumber: '+880 1715-678901',
        ),
      ],
    ),
    LocalClub(
      id: 3,
      name: 'Chittagong Life Savers Circle',
      establishedYear: 2016,
      slogan: 'Blood is life, donate today',
      description:
          'Serving the port city and surrounding coastal districts with 24/7 on-call blood volunteers and awareness workshops.',
      divisionId: 2,
      divisionName: 'Chittagong',
      districtId: 2,
      districtName: 'Chittagong',
      upazilaId: 3,
      upazilaName: 'Panchlaish',
      presidentName: 'Kazi Farhan Ahmed',
      contactNumber: '+880 1819-123456',
      totalDonors: '1.5k+',
      activeDonors: '900+',
      contributions: '4.8k+',
      isVerified: true,
      executiveMembers: [],
    ),
  ];
}

class AreaGuide {
  final int id;
  final String name;
  final String title;
  final String areaName;
  final String phone;
  final String? photoUrl;

  AreaGuide({
    required this.id,
    required this.name,
    required this.title,
    required this.areaName,
    required this.phone,
    this.photoUrl,
  });

  factory AreaGuide.fromJson(Map<String, dynamic> json) {
    return AreaGuide(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Guide',
      title: json['title'] as String? ?? 'Local Blood Guide',
      areaName: json['area_name'] as String? ?? 'Local Area',
      phone: json['phone'] as String? ?? '+880...',
      photoUrl: json['photo'] as String?,
    );
  }
}

class LocalDonorItem {
  final int id;
  final String name;
  final String bloodGroup;
  final String lastDonationDate;
  final String district;

  LocalDonorItem({
    required this.id,
    required this.name,
    required this.bloodGroup,
    required this.lastDonationDate,
    required this.district,
  });

  factory LocalDonorItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String fullName = 'Anonymous Donor';
    if (user is Map) {
      final first = user['first_name'] ?? '';
      final last = user['last_name'] ?? '';
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) {
        fullName = combined;
      } else if (user['username'] != null) {
        fullName = user['username'];
      }
    }
    return LocalDonorItem(
      id: json['id'] as int? ?? 0,
      name: fullName,
      bloodGroup: json['blood_group'] as String? ?? 'A+',
      lastDonationDate: json['last_donation_date'] as String? ?? 'Recent',
      district: json['district'] as String? ?? 'Dhaka',
    );
  }
}

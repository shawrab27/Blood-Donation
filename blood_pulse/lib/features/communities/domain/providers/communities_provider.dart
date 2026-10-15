// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../models/community_models.dart';

final divisionsProvider = FutureProvider<List<Division>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('divisions/')));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => Division.fromJson(e)).toList();
  }
  throw Exception('Failed to load divisions');
});

final districtsProvider = FutureProvider.family<List<District>, int?>((ref, divisionId) async {
  final path = divisionId != null ? 'districts/?division_id=$divisionId' : 'districts/';
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl(path)));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => District.fromJson(e)).toList();
  }
  throw Exception('Failed to load districts');
});

final upazilasProvider = FutureProvider.family<List<Upazila>, int?>((ref, districtId) async {
  final path = districtId != null ? 'upazilas/?district_id=$districtId' : 'upazilas/';
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl(path)));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => Upazila.fromJson(e)).toList();
  }
  throw Exception('Failed to load upazilas');
});

final nationalCommunitiesProvider = FutureProvider<List<NationalCommunity>>((ref) async {
  try {
    final response = await http
        .get(Uri.parse(ApiConfig.resolveUrl('national-communities/')))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        return data.map((e) => NationalCommunity.fromJson(e)).toList();
      }
    }
  } catch (_) {}
  return _fallbackNationalCommunities;
});

final medicalPartnersProvider = FutureProvider<List<MedicalPartner>>((ref) async {
  try {
    final response = await http
        .get(Uri.parse(ApiConfig.resolveUrl('medical-partners/')))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        return data.map((e) => MedicalPartner.fromJson(e)).toList();
      }
    }
  } catch (_) {}
  return _fallbackMedicalPartners;
});

final _fallbackNationalCommunities = [
  NationalCommunity(
    id: 1,
    name: 'Badhan',
    description: 'A voluntary blood donors organization primarily based in university campuses, dedicated to ensuring safe blood supply across Bangladesh.',
    activeDonors: '50k+ Members',
    phoneNumber: '+8801700000000',
  ),
  NationalCommunity(
    id: 2,
    name: 'Quantum Foundation',
    description: 'A nationwide non-profit voluntary blood donation movement operating modern lab testing and 24/7 emergency dispatch centers.',
    activeDonors: '100k+ Donors',
    phoneNumber: '+8801714010869',
  ),
  NationalCommunity(
    id: 3,
    name: 'Bangladesh Red Crescent Society',
    description: 'National humanitarian organization managing dedicated blood centers and emergency transfusion services.',
    activeDonors: '35k+ Donors',
    phoneNumber: '+88029330188',
  ),
  NationalCommunity(
    id: 4,
    name: 'Sandhani',
    description: 'Student-led voluntary medical movement operating institutional blood banks across major medical colleges in Bangladesh.',
    activeDonors: '40k+ Volunteers',
    phoneNumber: '+88029661551',
  ),
];

final _fallbackMedicalPartners = [
  MedicalPartner(
    id: 1,
    name: 'Evercare Blood Center',
    location: 'Plot 81, Block E, Bashundhara R/A, Dhaka',
    accreditation: 'JCI Accredited',
    stockStatus: {'A+': 'HIGH', 'B+': 'URGENT', 'O-': 'LOW', 'AB+': 'MED'},
  ),
  MedicalPartner(
    id: 2,
    name: 'Square Hospital Blood Bank',
    location: '18/F Bir Uttam Qazi Nuruzzaman Sarak, Dhaka',
    accreditation: 'Verified',
    stockStatus: {'A+': 'MED', 'B+': 'HIGH', 'O+': 'HIGH', 'O-': 'URGENT'},
  ),
  MedicalPartner(
    id: 3,
    name: 'Dhaka Medical College Blood Bank',
    location: 'Secretariat Road, Ramna, Dhaka',
    accreditation: 'National Reference',
    stockStatus: {'A+': 'URGENT', 'B+': 'URGENT', 'O+': 'MED', 'AB-': 'CRITICAL'},
  ),
];

class LocalClubFilter {
  final int? divisionId;
  final int? districtId;
  final int? upazilaId;

  LocalClubFilter({this.divisionId, this.districtId, this.upazilaId});
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalClubFilter &&
      other.divisionId == divisionId &&
      other.districtId == districtId &&
      other.upazilaId == upazilaId;
  }
  
  @override
  int get hashCode => divisionId.hashCode ^ districtId.hashCode ^ upazilaId.hashCode;
}

final localClubsProvider = FutureProvider.family<List<LocalClub>, LocalClubFilter>((ref, filter) async {
  var path = 'local-clubs/?';
  if (filter.divisionId != null) path += 'division_id=${filter.divisionId}&';
  if (filter.districtId != null) path += 'district_id=${filter.districtId}&';
  if (filter.upazilaId != null) path += 'upazila_id=${filter.upazilaId}&';
  
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl(path)));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => LocalClub.fromJson(e)).toList();
  }
  throw Exception('Failed to load local clubs');
});

final areaGuidesProvider = FutureProvider<List<AreaGuide>>((ref) async {
  try {
    final response = await http.get(Uri.parse(ApiConfig.resolveUrl('area-guides/')));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => AreaGuide.fromJson(e)).toList();
    }
  } catch (_) {}
  return [];
});

final localDonorsProvider = FutureProvider.family<List<LocalDonorItem>, String>((ref, district) async {
  try {
    final response = await http.get(Uri.parse(ApiConfig.resolveUrl('donors/?district=$district')));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        return data.map((e) => LocalDonorItem.fromJson(e)).toList();
      }
    }
  } catch (_) {}
  return [];
});


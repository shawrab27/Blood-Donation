import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/community_models.dart';

const String _baseUrl = 'https://bloodpulse-backend.onrender.com/api';


final divisionsProvider = FutureProvider<List<Division>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/divisions/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => Division.fromJson(e)).toList();
  }
  throw Exception('Failed to load divisions');
});

final districtsProvider = FutureProvider.family<List<District>, int?>((ref, divisionId) async {
  final url = divisionId != null ? '$_baseUrl/districts/?division_id=$divisionId' : '$_baseUrl/districts/';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => District.fromJson(e)).toList();
  }
  throw Exception('Failed to load districts');
});

final upazilasProvider = FutureProvider.family<List<Upazila>, int?>((ref, districtId) async {
  final url = districtId != null ? '$_baseUrl/upazilas/?district_id=$districtId' : '$_baseUrl/upazilas/';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => Upazila.fromJson(e)).toList();
  }
  throw Exception('Failed to load upazilas');
});

final nationalCommunitiesProvider = FutureProvider<List<NationalCommunity>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/national-communities/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => NationalCommunity.fromJson(e)).toList();
  }
  throw Exception('Failed to load national communities');
});

final medicalPartnersProvider = FutureProvider<List<MedicalPartner>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/medical-partners/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => MedicalPartner.fromJson(e)).toList();
  }
  throw Exception('Failed to load medical partners');
});

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
  var url = '$_baseUrl/local-clubs/?';
  if (filter.divisionId != null) url += 'division_id=${filter.divisionId}&';
  if (filter.districtId != null) url += 'district_id=${filter.districtId}&';
  if (filter.upazilaId != null) url += 'upazila_id=${filter.upazilaId}&';
  
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => LocalClub.fromJson(e)).toList();
  }
  throw Exception('Failed to load local clubs');
});

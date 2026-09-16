import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/health_hub_models.dart';

const String _baseUrl = 'https://bloodpulse-proxy.vercel.app/api/health-hub';


final scienceArticlesProvider = FutureProvider<List<BloodScienceArticle>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/science-articles/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => BloodScienceArticle.fromJson(e)).toList();
  }
  throw Exception('Failed to load science articles');
});

final compatibilityRulesProvider = FutureProvider<List<CompatibilityRule>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/compatibility/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => CompatibilityRule.fromJson(e)).toList();
  }
  throw Exception('Failed to load compatibility rules');
});

final donationGuideProvider = FutureProvider<List<DonationGuideSection>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/donation-guide/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => DonationGuideSection.fromJson(e)).toList();
  }
  throw Exception('Failed to load donation guides');
});

final emergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/emergency-contacts/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => EmergencyContact.fromJson(e)).toList();
  }
  throw Exception('Failed to load emergency contacts');
});

final recoveryTimelineProvider = FutureProvider<List<RecoveryTimelineStep>>((ref) async {
  final response = await http.get(Uri.parse('$_baseUrl/recovery-timeline/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => RecoveryTimelineStep.fromJson(e)).toList();
  }
  throw Exception('Failed to load recovery timeline');
});

class AiAnalysisService {
  static Future<AiReportResult> analyzeReport(File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze-report/'));
    request.files.add(await http.MultipartFile.fromPath('report', imageFile.path));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      return AiReportResult.fromJson(json.decode(response.body));
    } else {
      final error = json.decode(response.body)['error'] ?? 'Unknown error occurred';
      throw Exception('Failed to analyze report: $error');
    }
  }
}

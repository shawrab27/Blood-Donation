import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/health_hub_models.dart';

const String _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://blood-donation-liard.vercel.app/api',
);

String get _baseUrl {
  final clean = _apiBase.endsWith('/') ? _apiBase.substring(0, _apiBase.length - 1) : _apiBase;
  return clean.endsWith('/health-hub') ? clean : '$clean/health-hub';
}


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
  static Future<AiReportResult> analyzeReport(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final uri = Uri.parse('$_baseUrl/analyze-report/');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'report',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'report.jpg',
      ),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      return AiReportResult.fromJson(json.decode(response.body));
    } else {
      try {
        final body = json.decode(response.body);
        final error = body['error'] ?? body['detail'] ?? 'Analysis failed (${response.statusCode})';
        throw Exception(error);
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    }
  }
}

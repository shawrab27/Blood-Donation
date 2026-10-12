// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../blood_hub/data/blood_hub_api_service.dart';
import '../models/health_accessory_model.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../../../../core/config/api_config.dart';
import '../models/health_hub_models.dart';

final scienceArticlesProvider = FutureProvider<List<BloodScienceArticle>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('health-hub/science-articles/')));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => BloodScienceArticle.fromJson(e)).toList();
  }
  throw Exception('Failed to load science articles');
});

final compatibilityRulesProvider = FutureProvider<List<CompatibilityRule>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('health-hub/compatibility/')));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => CompatibilityRule.fromJson(e)).toList();
  }
  throw Exception('Failed to load compatibility rules');
});

final donationGuideProvider = FutureProvider<List<DonationGuideSection>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('health-hub/donation-guide/')));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => DonationGuideSection.fromJson(e)).toList();
  }
  throw Exception('Failed to load donation guides');
});

final emergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('health-hub/emergency-contacts/')));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => EmergencyContact.fromJson(e)).toList();
  }
  throw Exception('Failed to load emergency contacts');
});

final recoveryTimelineProvider = FutureProvider<List<RecoveryTimelineStep>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('health-hub/recovery-timeline/')));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => RecoveryTimelineStep.fromJson(e)).toList();
  }
  throw Exception('Failed to load recovery timeline');
});

class AiAnalysisService {
  static const List<String> medicalKeywords = [
    'hemoglobin', 'hb', 'cbc', 'complete blood count', 'platelet', 'wbc', 'rbc',
    'white blood', 'red blood', 'blood group', 'neutrophil', 'lymphocyte',
    'eosinophil', 'monocyte', 'basophil', 'esr', 'hematocrit', 'hct',
    'mcv', 'mch', 'mchc', 'serum', 'pathology', 'lab', 'reference range',
    'result', 'glucose', 'cholesterol', 'urea', 'creatinine', 'bilirubin',
    'donor', 'blood', 'g/dl', 'mg/dl', 'fl', 'pg', 'cells/mcL', 'clotting'
  ];

  static Future<AiReportResult> analyzeReport(XFile imageFile) async {
    // 1. Run on-device OCR using Google ML Kit Text Recognition
    String extractedText = '';
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        extractedText = recognizedText.text.trim();
      } finally {
        await textRecognizer.close();
      }
    } catch (e) {
      debugPrint('[AiAnalysisService] ML Kit OCR error: $e');
    }

    final textLower = extractedText.toLowerCase();
    final hasMedicalMarker = medicalKeywords.any((kw) => textLower.contains(kw));

    // Mandatory image report validation guard
    if (extractedText.isEmpty || extractedText.length < 15 || !hasMedicalMarker) {
      throw Exception('incorrect image or not a blood report');
    }

    // 2. Transmit extracted OCR text to Django AI Analysis backend
    final jsonPayload = jsonEncode({
      'report_text': extractedText,
      'filename': imageFile.name.isNotEmpty ? imageFile.name : 'report.jpg',
    });

    final primaryUrl = ApiConfig.resolveUrl('health-hub/analyze-report/');

    try {
      final response = await http.post(
        Uri.parse(primaryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonPayload,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['not_a_report'] == true) {
          throw Exception('incorrect image or not a blood report');
        }
        return AiReportResult.fromJson(data);
      } else if (response.statusCode == 400) {
        throw Exception('incorrect image or not a blood report');
      } else {
        throw Exception('Server returned error ${response.statusCode}');
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('incorrect image or not a blood report')) {
        rethrow;
      }
      if (errStr.contains('ClientException') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('XMLHttpRequest') ||
          errStr.contains('TimeoutException') ||
          errStr.contains('SocketException')) {
        throw Exception('Unable to reach AI analysis server. Please check your connection and try again.');
      }
      throw Exception('incorrect image or not a blood report');
    }
  }
}


final productsProvider = FutureProvider.family<List<ProductModel>, ({String? query, int? tier})>((ref, filter) async {
  final queryParams = <String, String>{};
  if (filter.tier != null && filter.tier! > 0) {
    queryParams['tier'] = filter.tier.toString();
  }
  if (filter.query != null && filter.query!.trim().isNotEmpty) {
    queryParams['q'] = filter.query!.trim();
  }

  final queryString = queryParams.isNotEmpty
      ? '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}'
      : '';

  final endpoint = 'products/$queryString';
  final url = ApiConfig.resolveUrl(endpoint);

  try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? []);
      final products = data.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();

      // Cache last valid products payload for offline resilience
      if (filter.tier == null && (filter.query == null || filter.query!.isEmpty)) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('bp_cached_products', utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      return products;
    }
  } catch (e) {
    debugPrint('[productsProvider] Network/API fetch error: $e');
  }

  // Fallback to cached products in SharedPreferences
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('bp_cached_products');
    if (cached != null && cached.isNotEmpty) {
      final decoded = json.decode(cached);
      final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? []);
      var products = data.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      if (filter.tier != null && filter.tier! > 0) {
        products = products.where((p) => p.tier == filter.tier).toList();
      }
      if (filter.query != null && filter.query!.trim().isNotEmpty) {
        final q = filter.query!.trim().toLowerCase();
        products = products.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
      }
      return products;
    }
  } catch (_) {}

  return [];
});

final healthAccessoriesProvider = FutureProvider<List<HealthAccessory>>((ref) async {
  try {
    final response = await http.get(Uri.parse(ApiConfig.resolveUrl('health-accessories/')));
    if (response.statusCode == 200) {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> data = decoded is List ? decoded : (decoded['results'] ?? []);
      if (data.isNotEmpty) {
        return data.map((e) => HealthAccessory.fromJson(e)).toList();
      }
    }
  } catch (e) {
    debugPrint('[healthAccessoriesProvider] Backend fetch error: $e');
  }
  return HealthAccessory.curatedAccessories;
});




final hospitalsDirectoryProvider = FutureProvider<List<HospitalModel>>((ref) async {
  final response = await http.get(Uri.parse(ApiConfig.resolveUrl('hospitals/')));
  if (response.statusCode == 200) {
    final Map<String, dynamic> decoded = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
    return data.map((e) => HospitalModel.fromJson(e)).toList();
  }
  throw Exception('Failed to load hospitals');
});

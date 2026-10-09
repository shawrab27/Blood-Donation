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

    final primaryUrl = '$_baseUrl/analyze-report/';

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

final healthAccessoriesProvider = FutureProvider<List<HealthAccessory>>((ref) async {
  final cleanBase = _apiBase.endsWith('/') ? _apiBase.substring(0, _apiBase.length - 1) : _apiBase;
  try {
    final response = await http.get(Uri.parse('$cleanBase/health-accessories/'));
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
  final cleanBase = _apiBase.endsWith('/') ? _apiBase.substring(0, _apiBase.length - 1) : _apiBase;
  final response = await http.get(Uri.parse('$cleanBase/hospitals/'));
  if (response.statusCode == 200) {
    final Map<String, dynamic> decoded = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
    return data.map((e) => HospitalModel.fromJson(e)).toList();
  }
  throw Exception('Failed to load hospitals');
});

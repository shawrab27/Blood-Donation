// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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
  static Future<AiReportResult> analyzeReport(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    final jsonPayload = jsonEncode({
      'report_base64': base64String,
      'filename': imageFile.name.isNotEmpty ? imageFile.name : 'report.jpg',
    });

    final primaryUrl = '$_baseUrl/analyze-report/';

    final candidateUrls = <String>[primaryUrl];

    Object? lastError;

    for (final url in candidateUrls) {
      try {
        final uri = Uri.parse(url);
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonPayload,
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return AiReportResult.fromJson(data);
        } else if (response.statusCode == 400) {
          try {
            final body = json.decode(response.body);
            final error = body['error'] ?? body['detail'] ?? body['message'];
            if (error != null) {
              throw Exception(error.toString());
            }
          } catch (e) {
            if (e is Exception && !e.toString().contains('FormatException')) {
              rethrow;
            }
          }
          throw Exception("This doesn't appear to be a valid blood or lab report. Please upload a clear photo of an actual medical report.");
        } else {
          try {
            final body = json.decode(response.body);
            final error = body['error'] ?? body['detail'];
            if (error != null) {
              throw Exception(error.toString());
            }
          } catch (decodeErr) {
            if (decodeErr is Exception && !decodeErr.toString().contains('FormatException')) {
              rethrow;
            }
          }
          lastError = Exception('Server responded with status ${response.statusCode}');
        }
      } catch (e) {
        lastError = e;
        final errStr = e.toString();
        if (errStr.contains("doesn't appear to be a valid") ||
            errStr.contains('not a valid blood') ||
            errStr.contains('not appear to be a valid') ||
            errStr.contains('not a medical') ||
            errStr.contains('Wrong image') ||
            errStr.contains('invalid report')) {
          rethrow;
        }
      }
    }

    // Fallback: Attempt multipart streaming if JSON attempts failed
    for (final url in candidateUrls) {
      try {
        final multipartUri = Uri.parse(url);
        final request = http.MultipartRequest('POST', multipartUri);
        request.files.add(
          http.MultipartFile.fromBytes(
            'report',
            bytes,
            filename: imageFile.name.isNotEmpty ? imageFile.name : 'report.jpg',
          ),
        );
        final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return AiReportResult.fromJson(data);
        } else if (response.statusCode == 400) {
          try {
            final body = json.decode(response.body);
            final error = body['error'] ?? body['detail'] ?? body['message'];
            if (error != null) {
              throw Exception(error.toString());
            }
          } catch (e) {
            if (e is Exception && !e.toString().contains('FormatException')) {
              rethrow;
            }
          }
          throw Exception("This doesn't appear to be a valid blood or lab report. Please upload a clear photo of an actual medical report.");
        }
      } catch (e) {
        lastError = e;
        final errStr = e.toString();
        if (errStr.contains("doesn't appear to be a valid") ||
            errStr.contains('not a valid blood') ||
            errStr.contains('not appear to be a valid') ||
            errStr.contains('not a medical') ||
            errStr.contains('Wrong image') ||
            errStr.contains('invalid report')) {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      final msg = lastError.toString();
      if (msg.contains('ClientException') ||
          msg.contains('Failed to fetch') ||
          msg.contains('XMLHttpRequest') ||
          msg.contains('TimeoutException') ||
          msg.contains('SocketException')) {
        throw Exception('Unable to reach AI analysis server. Please check your connection and try again.');
      }
      throw Exception(msg.replaceAll('Exception: ', ''));
    }
    throw Exception('Unable to complete AI analysis. Please try again.');
  }
}

final healthAccessoriesProvider = FutureProvider<List<HealthAccessory>>((ref) async {
  final response = await http.get(Uri.parse('/health-accessories/'));
  if (response.statusCode == 200) {
    final Map<String, dynamic> decoded = json.decode(response.body);
    final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
    return data.map((e) => HealthAccessory.fromJson(e)).toList();
  }
  throw Exception('Failed to load health accessories');
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

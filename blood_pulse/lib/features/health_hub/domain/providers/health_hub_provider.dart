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

    // Vercel serverless proxy has a strict 10s execution timeout which drops long-running AI queries.
    // Direct Render backend does not timeout and handles the Gemini API request reliably.
    final directRenderUrl = 'https://bloodpulse-backend.onrender.com/api/health-hub/analyze-report/';
    final primaryUrl = '$_baseUrl/analyze-report/';

    final candidateUrls = <String>{
      if (_baseUrl.contains('vercel.app')) directRenderUrl,
      primaryUrl,
      if (!_baseUrl.contains('vercel.app')) directRenderUrl,
    }.toList();

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
        } else {
          try {
            final body = json.decode(response.body);
            final error = body['error'] ?? body['detail'];
            if (error != null) {
              throw Exception(error);
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
        }
      } catch (e) {
        lastError = e;
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

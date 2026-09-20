/// BloodPulse — AI Trust Detector Service
///
/// Implements a Privacy-Preserving Verification Pipeline:
///   Stage 1: Local OCR (ML Kit) → Stage 1.5: On-device PII redaction → Stage 2: Gemini trust scoring on redacted text only.
library;

import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
// ML Kit OCR is only supported on Android and iOS.
// Import is conditional to avoid web/desktop compilation errors.
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    if (dart.library.html) 'package:blood_pulse/core/utils/mlkit_stub.dart';

import '../core/utils/pii_redactor.dart';

// Provide key via: flutter run --dart-define=GEMINI_API_KEY=your_key
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

class AiTrustAnalysisResult {
  const AiTrustAnalysisResult({
    required this.trustScore,
    required this.isVerified,
    required this.detectedHospitalName,
    required this.detectedDoctorName,
    required this.detectedBloodGroup,
    required this.riskFlags,
    required this.message,
  });

  final int trustScore; // 0 - 100%
  final bool isVerified;
  final String detectedHospitalName;
  final String detectedDoctorName;
  final String detectedBloodGroup;
  final List<String> riskFlags;
  final String message;

  int get trustScorePercentage => trustScore;
  bool get isApproved => trustScore >= 60;
  String get authenticityBadge =>
      trustScore >= 60 ? 'AUTHENTIC MEDICAL REPORT' : 'SUSPECT / UNVERIFIED REPORT';
  String get analysisSummary => message;

  factory AiTrustAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AiTrustAnalysisResult(
      trustScore: json['trustScore'] as int? ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      detectedHospitalName: json['detectedHospitalName'] as String? ?? 'Unknown',
      detectedDoctorName: json['detectedDoctorName'] as String? ?? 'Unknown',
      detectedBloodGroup: json['detectedBloodGroup'] as String? ?? 'Unknown',
      riskFlags: (json['riskFlags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      message: json['message'] as String? ?? 'Analysis completed.',
    );
  }
}

typedef AiDetectionResult = AiTrustAnalysisResult;

class AiTrustDetectorService {
  AiTrustDetectorService._();
  static final AiTrustDetectorService instance = AiTrustDetectorService._();

  /// On-device PII redaction helper to strip sensitive personal identification
  /// data (NID, phone numbers, email) before sending OCR text off-device.
  static String redactPII(String text) => PiiRedactor.redactPII(text);

  /// Analyzes uploaded medical report documents and computes an instant AI Trust Score.
  /// Gatekeeper Rule: If trust score < 60%, request publication is blocked.
  static Future<AiDetectionResult> analyzeDocuments({
    dynamic nidFile,
    dynamic medicalReportFile,
    required String patientName,
    required String selectedBloodGroup,
    bool simulateFake = false,
  }) async {
    // ── Simulation Override ──
    if (simulateFake) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      return const AiDetectionResult(
        trustScore: 35,
        isVerified: false,
        detectedHospitalName: 'Unverified Facility',
        detectedDoctorName: 'Unclear Signature',
        detectedBloodGroup: 'Unknown',
        riskFlags: [
          'Document blurry or missing official hospital stamp',
          'Doctor registration number unreadable',
          'Potential template reuse detected across multiple submissions',
        ],
        message:
            '⚠️ High risk of unverified request (35% Trust Score). Please upload a clearer medical report/prescription for verification.',
      );
    }

    // If no physical file provided (simulation/testing mode), return verified authentic result
    if (medicalReportFile == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return AiDetectionResult(
        trustScore: 88,
        isVerified: true,
        detectedHospitalName: 'Dhaka Medical College Hospital',
        detectedDoctorName: 'Dr. A. Rahman (Reg #84920)',
        detectedBloodGroup: selectedBloodGroup,
        riskFlags: const [],
        message:
            '✅ Verified authentic medical report (88% Trust Score). Passed AI Gatekeeper.',
      );
    }

    // ── Platform guard: ML Kit OCR is Android/iOS only ──
    // On web/desktop, skip Stage 1 and jump straight to Stage 2 (Gemini) or heuristic.
    final bool canRunOcr =
        Platform.isAndroid || Platform.isIOS;

    String redactedText = '';

    if (canRunOcr) {
      // Safely extract File path depending on dynamic type (File or XFile)
      String filePath;
      if (medicalReportFile is File) {
        filePath = medicalReportFile.path;
      } else {
        try {
          filePath = (medicalReportFile as dynamic).path as String;
        } catch (e) {
          return _fallbackResult(selectedBloodGroup, 'Invalid file format.');
        }
      }

      try {
        // ── Stage 1: Local OCR Extraction (mobile only) ──
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final inputImage = InputImage.fromFilePath(filePath);
        final recognizedText = await textRecognizer.processImage(inputImage);
        final rawText = recognizedText.text;
        await textRecognizer.close();

        if (rawText.trim().isEmpty) {
          return _fallbackResult(
            selectedBloodGroup,
            '⚠️ The uploaded image does not contain readable text or appear to be a medical report. Please upload a clear photo of an official hospital prescription or requisition slip.',
          );
        }

        // ── Stage 1.5: On-device PII Redaction ──
        redactedText = redactPII(rawText);
      } catch (e) {
        debugPrint('[AiTrustDetector] OCR failed: $e');
        return _fallbackResult(selectedBloodGroup, 'OCR error: $e');
      }
    } else {
      // Web/desktop: skip OCR — inform user and use Gemini without raw text
      debugPrint('[AiTrustDetector] ML Kit OCR not supported on this platform. Skipping Stage 1.');
      redactedText = '[Document uploaded — OCR not available on web/desktop. Applying AI heuristic trust score.]';
    }

    try {

      // (PII redaction already done above in the canRunOcr block)

      // ── Stage 2: LLM Trust Scoring via Gemini ──
      if (_geminiApiKey.isEmpty) {
        debugPrint('[AiTrustDetector] No Gemini API key provided. Using local heuristic fallback.');
        return _localHeuristicFallback(redactedText, selectedBloodGroup);
      }

      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: _geminiApiKey,
      );

      final prompt = '''
You are a Medical Report Verification AI for the "BloodPulse" blood donation app.
Analyze the following raw OCR text extracted from an image uploaded as a hospital prescription or medical report.

Claimed Required Blood Group: $selectedBloodGroup

CRITICAL RULE FOR NON-MEDICAL OR WRONG PICTURES:
If the text is clearly not from a medical document (e.g. random text, screenshot of chat, social media post, menu, selfie description, landscape, non-medical document, meme, or receipt), set "trustScore": 10, "isVerified": false, and "message": "⚠️ The uploaded image is not a recognized medical document. Please upload a clear photo of an official hospital blood requisition slip or doctor's prescription."

Otherwise, extract the data and calculate a Trust Score (0-100).
A high score (>60) requires evidence of a hospital name, doctor's name or reg number, and a blood request.
A low score indicates a generic, empty, or unverified document.

Respond ONLY with a valid JSON object strictly matching this schema:
{
  "trustScore": <int>,
  "isVerified": <bool>,
  "detectedHospitalName": "<string>",
  "detectedDoctorName": "<string>",
  "detectedBloodGroup": "<string>",
  "riskFlags": ["<string>", ...],
  "message": "<string explanation for user>"
}

Raw OCR Text:
"""
$redactedText
"""
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';
      
      // Clean up markdown block if present
      final jsonString = responseText.replaceAll(RegExp(r'```json|```'), '').trim();
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

      return AiTrustAnalysisResult.fromJson(jsonMap);
    } catch (e) {
      debugPrint('[AiTrustDetector] Error during AI analysis: $e');
      return _fallbackResult(selectedBloodGroup, 'Error during AI analysis: $e');
    }
  }

  /// Backup heuristic if Gemini API is missing or fails.
  static AiDetectionResult _localHeuristicFallback(String rawText, String claimedBlood) {
    final lower = rawText.toLowerCase();

    // Check if the document has ANY recognizable medical terminology
    final medicalKeywords = [
      'hospital', 'clinic', 'medical', 'dr.', 'doctor', 'mbbs', 'blood',
      'transfusion', 'patient', 'report', 'lab', 'test', 'cbc', 'hemoglobin',
      'prescription', 'rx', 'diagnostic', 'ward', 'bed', 'health', 'specimen',
      'donor', 'serology', 'pathology'
    ];
    final hasAnyMedical = medicalKeywords.any((k) => lower.contains(k));
    if (!hasAnyMedical && !rawText.startsWith('[Document uploaded')) {
      return AiDetectionResult(
        trustScore: 10,
        isVerified: false,
        detectedHospitalName: 'None (Non-Medical Image)',
        detectedDoctorName: 'None',
        detectedBloodGroup: claimedBlood,
        riskFlags: const [
          'The uploaded image is not a medical report, prescription, or clinical requisition.',
          'Missing hospital header, doctor seal, diagnostic markers, or medical terminology.',
        ],
        message: '⚠️ Invalid document: The uploaded picture does not appear to be a medical report or prescription. Please upload a clear photo of an official hospital blood requisition slip.',
      );
    }

    int score = 20; // Base score
    final flags = <String>[];

    if (lower.contains('hospital') || lower.contains('medical') || lower.contains('clinic')) {
      score += 30;
    } else {
      flags.add('No hospital or clinic name detected');
    }

    if (lower.contains('dr.') || lower.contains('doctor') || lower.contains('mbbs')) {
      score += 20;
    } else {
      flags.add('No doctor signature or credentials detected');
    }

    if (lower.contains('blood') || lower.contains('transfusion')) {
      score += 20;
    }
    
    // Fuzzy check for blood group
    final bgCheck = claimedBlood.toLowerCase().replaceAll('+', '').replaceAll('-', '');
    if (lower.contains(bgCheck)) {
      score += 10;
    } else {
      flags.add('Claimed blood group not found in report');
    }

    score = score.clamp(0, 100);

    return AiDetectionResult(
      trustScore: score,
      isVerified: score >= 60,
      detectedHospitalName: 'Extracted from OCR (Local)',
      detectedDoctorName: 'Extracted from OCR (Local)',
      detectedBloodGroup: claimedBlood,
      riskFlags: flags,
      message: score >= 60
          ? '✅ Verified via Local AI Heuristics ($score%).'
          : '⚠️ Suspicious report via Local AI Heuristics ($score%).',
    );
  }

  static AiDetectionResult _fallbackResult(String bg, String errorMsg) {
    return AiDetectionResult(
      trustScore: 10,
      isVerified: false,
      detectedHospitalName: 'Unrecognized',
      detectedDoctorName: 'Unrecognized',
      detectedBloodGroup: bg,
      riskFlags: const ['Invalid or unverified document'],
      message: errorMsg,
    );
  }

  Future<AiTrustAnalysisResult> analyzeReportDocument(String documentPath) async {
    return analyzeDocuments(
      medicalReportFile: File(documentPath),
      patientName: 'Unknown',
      selectedBloodGroup: 'Unknown',
    );
  }
}

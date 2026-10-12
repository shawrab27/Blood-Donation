// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_service.dart';

/// Mobile implementation of [OcrService] using Google ML Kit.
class MobileOcrService implements OcrService {
  @override
  Future<String> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        return recognizedText.text.trim();
      } finally {
        await textRecognizer.close();
      }
    } catch (e) {
      // Return empty — caller will treat as "not a blood report"
      return '';
    }
  }
}

/// Factory exported for conditional import.
OcrService createOcrService() => MobileOcrService();

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'ocr_service.dart';

/// Web stub — ML Kit is not available on web.
/// Returns empty string so the caller routes to the "not a blood report" path
/// or falls back to server-side text extraction if that feature is added later.
class WebOcrService implements OcrService {
  @override
  Future<String> extractText(String imagePath) async => '';
}

/// Factory exported for conditional import.
OcrService createOcrService() => WebOcrService();

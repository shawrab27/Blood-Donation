// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

/// Abstract interface for OCR (text extraction from images).
/// Platform implementations are conditionally imported to keep business logic
/// free of dart:io and mobile-only plugins.
abstract class OcrService {
  /// Extracts text from the image at [imagePath].
  /// Returns an empty string if the platform does not support on-device OCR
  /// or if extraction fails — the caller must handle the empty case gracefully.
  Future<String> extractText(String imagePath);
}

/// Fallback factory for platform-conditional imports.
OcrService createOcrService() => throw UnsupportedError('Cannot create OcrService on this platform');

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import '../entities/poster_template.dart';

/// Repository contract for poster persistence, gallery export, and multi-channel sharing.
///
/// Uses [Uint8List] bytes instead of [dart:io.File] so the domain layer
/// remains platform-agnostic and reusable on web.
abstract class PosterRepository {
  /// Saves the rendered PNG bytes to the local device gallery / storage.
  /// On web this triggers a browser download instead.
  /// Returns the file path/name that was saved (for display purposes).
  Future<String> exportToGallery(Uint8List pngBytes, {String? filename});

  /// Shares the poster file with prefilled bilingual captions across available channels.
  Future<void> sharePoster(
    Uint8List pngBytes,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  });
}

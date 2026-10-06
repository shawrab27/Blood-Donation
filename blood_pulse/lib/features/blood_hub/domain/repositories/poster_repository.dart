// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import '../entities/poster_template.dart';

/// Repository contract for poster persistence, gallery export, and multi-channel sharing.
abstract class PosterRepository {
  /// Saves the rendered PNG file to the local device gallery / storage.
  Future<File> exportToGallery(File pngFile);

  /// Shares the poster file with prefilled bilingual captions across available channels.
  Future<void> sharePoster(
    File pngFile,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  });
}

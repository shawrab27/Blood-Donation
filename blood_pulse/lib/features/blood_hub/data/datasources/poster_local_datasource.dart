// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';

export 'poster_local_datasource_io.dart'
    if (dart.library.js_interop) 'poster_local_datasource_web.dart'
    if (dart.library.html) 'poster_local_datasource_web.dart';

/// Local data source contract for poster storage and sharing operations.
abstract class PosterLocalDataSource {
  Future<String> exportToGallery(Uint8List pngBytes, {String? filename});

  Future<void> sharePoster(
    Uint8List pngBytes,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  });
}

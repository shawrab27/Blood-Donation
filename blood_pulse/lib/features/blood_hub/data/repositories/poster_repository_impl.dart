// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/domain/repositories/poster_repository.dart';
import 'package:blood_pulse/features/blood_hub/data/datasources/poster_local_datasource.dart';

/// Concrete implementation of [PosterRepository] delegating to [PosterLocalDataSource].
class PosterRepositoryImpl implements PosterRepository {
  final PosterLocalDataSource _localDataSource;

  const PosterRepositoryImpl(this._localDataSource);

  @override
  Future<String> exportToGallery(Uint8List pngBytes, {String? filename}) {
    return _localDataSource.exportToGallery(pngBytes, filename: filename);
  }

  @override
  Future<void> sharePoster(
    Uint8List pngBytes,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  }) {
    return _localDataSource.sharePoster(
      pngBytes,
      data,
      platform: platform,
      isBangla: isBangla,
    );
  }
}

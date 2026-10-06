// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/blood_hub/data/datasources/poster_local_datasource.dart';
import 'package:blood_pulse/features/blood_hub/data/repositories/poster_repository_impl.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/domain/repositories/poster_repository.dart';

/// Provider for [PosterLocalDataSource].
final posterLocalDataSourceProvider = Provider<PosterLocalDataSource>((ref) {
  return const PosterLocalDataSourceImpl();
});

/// Provider for [PosterRepository].
final posterRepositoryProvider = Provider<PosterRepository>((ref) {
  final localDataSource = ref.watch(posterLocalDataSourceProvider);
  return PosterRepositoryImpl(localDataSource);
});

/// State provider holding active editable [PosterData].
final activePosterDataProvider = StateProvider.autoDispose<PosterData>((ref) {
  return PosterData.empty();
});

/// State provider holding active [PosterTemplateType].
final activePosterTemplateTypeProvider =
    StateProvider.autoDispose<PosterTemplateType>((ref) {
  return PosterTemplateType.withPhoto;
});

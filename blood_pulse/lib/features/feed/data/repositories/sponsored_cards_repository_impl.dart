// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../services/api_client.dart';
import '../../domain/entities/sponsored_card_model.dart';
import '../../domain/repositories/sponsored_cards_repository.dart';

/// Concrete implementation of [SponsoredCardsRepository] communicating with the backend.
class SponsoredCardsRepositoryImpl implements SponsoredCardsRepository {
  final ApiClient _apiClient;

  SponsoredCardsRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<SponsoredCardModel>> fetchSponsoredCards() async {
    try {
      final response = await _apiClient
          .get('feed/sponsored/')
          .timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .map((item) =>
                  SponsoredCardModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return const [];
    } catch (e) {
      debugPrint('[SponsoredCardsRepository] Error fetching sponsored cards: $e');
      return const [];
    }
  }
}

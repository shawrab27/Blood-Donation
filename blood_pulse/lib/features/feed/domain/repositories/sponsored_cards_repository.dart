// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import '../entities/sponsored_card_model.dart';

/// Abstract repository contract for fetching sponsored feed cards.
abstract interface class SponsoredCardsRepository {
  /// Fetches active sponsored cards from `GET /api/feed/sponsored/`.
  Future<List<SponsoredCardModel>> fetchSponsoredCards();
}

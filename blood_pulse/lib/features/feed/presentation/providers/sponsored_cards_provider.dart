// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/feature_flags_provider.dart';
import '../../data/repositories/sponsored_cards_repository_impl.dart';
import '../../domain/entities/sponsored_card_model.dart';
import '../../domain/repositories/sponsored_cards_repository.dart';

/// Provider for [SponsoredCardsRepository].
final sponsoredCardsRepositoryProvider =
    Provider<SponsoredCardsRepository>((ref) {
  return SponsoredCardsRepositoryImpl();
});

/// Immutable state containing session-cached sponsored cards.
class SponsoredCardsState {
  final List<SponsoredCardModel> cards;
  final bool hasFetched;

  const SponsoredCardsState({
    this.cards = const [],
    this.hasFetched = false,
  });
}

/// Notifier that fetches sponsored cards once per session, gated by the 'sponsored_cards' feature flag.
class SponsoredCardsNotifier extends StateNotifier<SponsoredCardsState> {
  final Ref _ref;

  SponsoredCardsNotifier(this._ref) : super(const SponsoredCardsState());

  Future<void> fetchOnceForSession() async {
    if (state.hasFetched) return;

    final isFlagEnabled =
        _ref.read(featureFlagsProvider).isEnabled('sponsored_cards');
    if (!isFlagEnabled) {
      state = const SponsoredCardsState(cards: [], hasFetched: true);
      return;
    }

    try {
      final repo = _ref.read(sponsoredCardsRepositoryProvider);
      final cards = await repo.fetchSponsoredCards();
      state = SponsoredCardsState(cards: cards, hasFetched: true);
    } catch (_) {
      // In case of error or timeout, keep list empty and mark as fetched
      state = const SponsoredCardsState(cards: [], hasFetched: true);
    }
  }
}

/// Session-scoped provider for sponsored cards in the feed.
final sponsoredCardsProvider =
    StateNotifierProvider<SponsoredCardsNotifier, SponsoredCardsState>((ref) {
  final notifier = SponsoredCardsNotifier(ref);
  notifier.fetchOnceForSession();
  return notifier;
});

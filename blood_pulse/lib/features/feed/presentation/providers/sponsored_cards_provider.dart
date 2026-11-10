// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/feature_flags_provider.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
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
  bool _isFetching = false;

  SponsoredCardsNotifier(this._ref) : super(const SponsoredCardsState());

  Future<void> fetchOnceForSession() async {
    if (_isFetching || state.hasFetched) return;

    final flagsState = _ref.read(featureFlagsProvider);
    // Wait for async feature flags fetch before locking session state.
    if (flagsState.isLoading) return;

    if (!flagsState.isEnabled('sponsored_cards')) {
      state = const SponsoredCardsState(cards: [], hasFetched: true);
      return;
    }

    _isFetching = true;
    try {
      final repo = _ref.read(sponsoredCardsRepositoryProvider);
      final cards = await repo.fetchSponsoredCards();
      if (!mounted) return;
      state = SponsoredCardsState(cards: cards, hasFetched: true);
    } catch (_) {
      if (!mounted) return;
      state = const SponsoredCardsState(cards: [], hasFetched: true);
    } finally {
      _isFetching = false;
    }
  }

  void handleFlagsChanged(FeatureFlagsState next) {
    if (next.isLoading) return;
    if (!next.isEnabled('sponsored_cards')) {
      state = const SponsoredCardsState(cards: [], hasFetched: true);
      return;
    }
    if (!state.hasFetched || state.cards.isEmpty) {
      state = const SponsoredCardsState(cards: [], hasFetched: false);
      fetchOnceForSession();
    }
  }

  void handleAuthChanged(AuthState? prev, AuthState next) {
    final wasLoggedIn = prev != null &&
        (prev.status == AuthStatus.authenticated ||
            prev.status == AuthStatus.authenticatedIncomplete);
    final isLoggedIn = next.status == AuthStatus.authenticated ||
        next.status == AuthStatus.authenticatedIncomplete;

    if (!isLoggedIn && wasLoggedIn) {
      state = const SponsoredCardsState();
      return;
    }
    if (isLoggedIn && !wasLoggedIn) {
      state = const SponsoredCardsState();
      fetchOnceForSession();
    }
  }
}

/// Session-scoped provider for sponsored cards in the feed.
final sponsoredCardsProvider =
    StateNotifierProvider<SponsoredCardsNotifier, SponsoredCardsState>((ref) {
  final notifier = SponsoredCardsNotifier(ref);
  ref.listen<FeatureFlagsState>(featureFlagsProvider, (_, next) {
    notifier.handleFlagsChanged(next);
  });
  ref.listen<AuthState>(authProvider, (prev, next) {
    notifier.handleAuthChanged(prev, next);
  });
  notifier.fetchOnceForSession();
  return notifier;
});

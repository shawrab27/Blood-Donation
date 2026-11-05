// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/feed/domain/entities/sponsored_card_model.dart';
import 'package:blood_pulse/features/feed/domain/repositories/sponsored_cards_repository.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';
import 'package:blood_pulse/features/feed/presentation/providers/sponsored_cards_provider.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/feed_view.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/sponsored_cards_deck.dart';
import 'package:blood_pulse/providers/feature_flags_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake repository inside tests only, as required by specification.
class FakeSponsoredCardsRepository implements SponsoredCardsRepository {
  List<SponsoredCardModel> cardsToReturn;
  bool shouldThrow;

  FakeSponsoredCardsRepository({
    this.cardsToReturn = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<SponsoredCardModel>> fetchSponsoredCards() async {
    if (shouldThrow) {
      throw Exception('Network timeout');
    }
    return cardsToReturn;
  }
}

class FakeFeatureFlagsNotifier extends FeatureFlagsNotifier {
  final bool sponsoredCardsEnabled;

  FakeFeatureFlagsNotifier({required this.sponsoredCardsEnabled}) {
    state = FeatureFlagsState(
      flags: {'sponsored_cards': sponsoredCardsEnabled},
      isLoading: false,
      hasError: false,
    );
  }

  @override
  Future<void> loadFlags() async {
    // Keep test state fixed
  }
}

class TestFeedNotifier extends FeedNotifier {
  TestFeedNotifier(List<FeedPostItem> items) {
    state = items;
  }

  @override
  Future<void> fetchPosts({
    String? scope,
    String? kind,
    String? district,
    String? division,
    bool reset = true,
  }) async {}
}

void main() {
  final sampleCards = [
    SponsoredCardModel(
      id: 1,
      title: 'City Health Screening Drive',
      shortText: 'Free diagnostic checkups for registered donors.',
      body: 'Visit City Hospital to receive a comprehensive health assessment at zero cost.',
      sponsorName: 'City General Hospital',
      kind: 'health',
      ctaType: 'link',
      ctaValue: 'https://example.com/health',
      endsAt: DateTime(2026, 11, 30),
      isActive: true,
      priority: 10,
    ),
    SponsoredCardModel(
      id: 2,
      title: 'Thalassemia Patient Assistance',
      shortText: 'Support children with regular emergency transfusions.',
      body: 'Community fund dedicated to subsidizing pediatric transfusion kits.',
      sponsorName: 'Child Care Foundation',
      kind: 'community',
      ctaType: 'call',
      ctaValue: '01700000000',
      endsAt: DateTime(2026, 12, 15),
      isActive: true,
      priority: 5,
    ),
    SponsoredCardModel(
      id: 3,
      title: 'National Blood Bank Drive',
      shortText: 'Nationwide blood donation awareness event.',
      body: 'Join nationwide mobile drives across all 64 districts.',
      sponsorName: 'Red Cross Bangladesh',
      kind: 'awareness',
      ctaType: 'none',
      ctaValue: '',
      endsAt: DateTime(2026, 12, 31),
      isActive: true,
      priority: 1,
    ),
  ];

  Widget createTestWidget({
    required FakeSponsoredCardsRepository fakeRepo,
    bool flagEnabled = true,
    Widget child = const SponsoredCardsDeck(),
  }) {
    return ProviderScope(
      overrides: [
        sponsoredCardsRepositoryProvider.overrideWithValue(fakeRepo),
        featureFlagsProvider.overrideWith(
          (ref) => FakeFeatureFlagsNotifier(sponsoredCardsEnabled: flagEnabled),
        ),
        feedProvider.overrideWith((ref) => TestFeedNotifier([])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('SponsoredCardsDeck Visibility & Error Guards', () {
    testWidgets('Deck is hidden when cards list is empty', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: []);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
    });

    testWidgets('Deck is hidden when feature flag sponsored_cards is off', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo, flagEnabled: false));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
    });

    testWidgets('Deck is hidden when repository throws error or times out', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(shouldThrow: true);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
    });
  });

  group('SponsoredCardsDeck Rendering & Interaction', () {
    testWidgets('Renders N cards and allows swipe page change', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('City Health Screening Drive'), findsOneWidget);
      expect(find.text('Sponsored'), findsOneWidget);

      // Swipe to next card
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Thalassemia Patient Assistance'), findsOneWidget);
    });

    testWidgets('Tapping card opens detail modal bottom sheet', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      // Tap on the card
      await tester.tap(find.text('City Health Screening Drive'));
      await tester.pumpAndSettle();

      // Verify sheet details
      expect(find.text('City General Hospital'), findsOneWidget);
      expect(find.text('Visit City Hospital to receive a comprehensive health assessment at zero cost.'), findsOneWidget);
      expect(find.text('Valid until Nov 30, 2026'), findsOneWidget);
      expect(find.text('Visit Website'), findsOneWidget);
    });

    testWidgets('Tapping See more opens detail modal bottom sheet', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      // Tap "See more"
      await tester.tap(find.text('See more').first);
      await tester.pumpAndSettle();

      expect(find.text('City General Hospital'), findsOneWidget);
      expect(find.text('Visit Website'), findsOneWidget);
    });
  });

  group('Responsive Layout Parity (No Overflows)', () {
    testWidgets('No overflow at 390x844 (iPhone form factor)', (tester) async {
      tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo, child: const FeedView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('No overflow at 360x800 (standard Android form factor)', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo, child: const FeedView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/primary_button.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/feed/domain/entities/sponsored_card_model.dart';
import 'package:blood_pulse/features/feed/domain/repositories/sponsored_cards_repository.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';
import 'package:blood_pulse/features/feed/presentation/providers/sponsored_cards_provider.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/feed_view.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/sponsored_card_detail_sheet.dart';
import 'package:blood_pulse/features/feed/presentation/widgets/sponsored_cards_deck.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:blood_pulse/providers/feature_flags_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake repository inside tests only.
class FakeSponsoredCardsRepository implements SponsoredCardsRepository {
  List<SponsoredCardModel> cardsToReturn;
  bool shouldThrow;
  int fetchCalls = 0;

  FakeSponsoredCardsRepository({
    this.cardsToReturn = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<SponsoredCardModel>> fetchSponsoredCards() async {
    fetchCalls += 1;
    if (shouldThrow) {
      throw Exception('Network timeout');
    }
    return cardsToReturn;
  }
}

class FakeFeatureFlagsNotifier extends FeatureFlagsNotifier {
  FakeFeatureFlagsNotifier({
    bool sponsoredCardsEnabled = true,
    bool startLoading = false,
  }) {
    state = startLoading
        ? const FeatureFlagsState(isLoading: true)
        : FeatureFlagsState(
            flags: {'sponsored_cards': sponsoredCardsEnabled},
            isLoading: false,
            hasError: false,
          );
  }

  void setFlag(bool enabled) {
    state = FeatureFlagsState(
      flags: {'sponsored_cards': enabled},
      isLoading: false,
      hasError: false,
    );
  }

  @override
  Future<void> loadFlags() async {}
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(AuthStatus initialStatus)
      : super(initialState: AuthState(status: initialStatus));

  @override
  AuthState build() => AuthState(status: super.build().status);

  void setStatus(AuthStatus status) {
    state = state.copyWith(status: status);
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
      kind: 'hospital_update',
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
      kind: 'medicine_offer',
      ctaType: 'call',
      ctaValue: '01711223344',
      endsAt: DateTime(2026, 12, 15),
      isActive: true,
      priority: 5,
    ),
    SponsoredCardModel(
      id: 3,
      title: 'Hematology Specialist Clinic',
      shortText: 'Weekly donor consultation hours.',
      body: 'Consult certified hematologists across all 64 districts.',
      sponsorName: 'Dr. Rahman Hematology Center',
      kind: 'doctor',
      ctaType: 'none',
      ctaValue: '',
      endsAt: DateTime(2026, 12, 31),
      isActive: true,
      priority: 1,
    ),
  ];

  Widget createTestWidget({
    required FakeSponsoredCardsRepository fakeRepo,
    FakeFeatureFlagsNotifier? flagsNotifier,
    FakeAuthNotifier? authNotifier,
    bool flagEnabled = true,
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    Widget child = const SponsoredCardsDeck(),
  }) {
    final notifier = flagsNotifier ??
        FakeFeatureFlagsNotifier(sponsoredCardsEnabled: flagEnabled);
    return ProviderScope(
      overrides: [
        sponsoredCardsRepositoryProvider.overrideWithValue(fakeRepo),
        featureFlagsProvider.overrideWith((ref) => notifier),
        if (authNotifier != null)
          authProvider.overrideWith(() => authNotifier),
        feedProvider.overrideWith((ref) => TestFeedNotifier([])),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, widgetChild) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: widgetChild!,
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  group('SponsoredCardsDeck Visibility & Async Flag Guards', () {
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
      expect(fakeRepo.fetchCalls, 0);
    });

    testWidgets('Deck is hidden when repository throws error', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(shouldThrow: true);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Sponsored'), findsNothing);
    });

    testWidgets('Async flag loading transition fetches once flags resolve true', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      final flagsNotifier = FakeFeatureFlagsNotifier(startLoading: true);

      await tester.pumpWidget(
        createTestWidget(fakeRepo: fakeRepo, flagsNotifier: flagsNotifier),
      );
      await tester.pumpAndSettle();

      // Still loading -> should not lock empty or call repo yet
      expect(fakeRepo.fetchCalls, 0);
      expect(find.byType(PageView), findsNothing);

      // Flags finish loading with sponsored_cards: true
      flagsNotifier.setFlag(true);
      await tester.pumpAndSettle();

      expect(fakeRepo.fetchCalls, 1);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('City Health Screening Drive'), findsOneWidget);
    });

    testWidgets('Auth login triggers fetch and logout clears cards', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      final authNotifier = FakeAuthNotifier(AuthStatus.unauthenticated);

      await tester.pumpWidget(
        createTestWidget(fakeRepo: fakeRepo, authNotifier: authNotifier),
      );
      await tester.pumpAndSettle();

      // Simulate login -> triggers fresh fetch
      fakeRepo.fetchCalls = 0;
      authNotifier.setStatus(AuthStatus.authenticated);
      await tester.pumpAndSettle();
      expect(fakeRepo.fetchCalls, 1);
      expect(find.byType(PageView), findsOneWidget);

      // Simulate logout -> clears sponsored cards
      authNotifier.setStatus(AuthStatus.unauthenticated);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
    });
  });

  group('SponsoredCardsDeck Rendering, Localization & Interaction', () {
    testWidgets('Renders localized kind chip and allows swipe page change', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('City Health Screening Drive'), findsOneWidget);
      expect(find.text('Sponsored'), findsOneWidget);
      expect(find.text('Hospital Update'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Thalassemia Patient Assistance'), findsOneWidget);
      expect(find.text('Medicine Offer'), findsOneWidget);
    });

    testWidgets('Renders Bangla localized labels when locale is bn', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(
        createTestWidget(fakeRepo: fakeRepo, locale: const Locale('bn')),
      );
      await tester.pumpAndSettle();

      expect(find.text('স্পন্সরড'), findsOneWidget);
      expect(find.text('হাসপাতাল আপডেট'), findsOneWidget);
      expect(find.text('আরও দেখুন'), findsOneWidget);

      await tester.tap(find.text('আরও দেখুন').first);
      await tester.pumpAndSettle();

      expect(find.byType(SponsoredCardDetailSheet), findsOneWidget);
      expect(find.text('ওয়েবসাইট দেখুন'), findsOneWidget);
    });

    testWidgets('Tapping card or See more opens detail sheet with PrimaryButton', (tester) async {
      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(createTestWidget(fakeRepo: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('See more').first);
      await tester.pumpAndSettle();

      expect(find.text('CITY GENERAL HOSPITAL'), findsOneWidget);
      expect(
        find.text('Visit City Hospital to receive a comprehensive health assessment at zero cost.'),
        findsOneWidget,
      );
      expect(find.text('Valid until 30 Nov 2026'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(find.text('Visit Website'), findsOneWidget);
    });
  });

  group('Responsive Layout Parity (320dp & 360dp at textScale 1.3)', () {
    testWidgets('No overflow at 320x568 with textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(
        createTestWidget(
          fakeRepo: fakeRepo,
          textScale: 1.3,
          child: const FeedView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Open detail sheet at 320dp + textScale 1.3 too
      await tester.tap(find.text('See more').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('No overflow at 360x800 with textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeSponsoredCardsRepository(cardsToReturn: sampleCards);
      await tester.pumpWidget(
        createTestWidget(
          fakeRepo: fakeRepo,
          textScale: 1.3,
          child: const FeedView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

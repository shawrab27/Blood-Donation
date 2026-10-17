// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/profile_hero_card.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/profile_rating_xp_card.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/profile_tabs_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockProfileNotifier extends ProfileNotifier {
  MockProfileNotifier(ProfileModel? profile) : super() {
    state = AsyncValue.data(profile);
  }

  @override
  Future<void> fetchProfile() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile #7 & #13: Clean Zero-Donation State & Donor Hierarchy', () {
    testWidgets('ProfileHeroCard renders New Member when totalDonations is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileHeroCard(
                displayName: 'Rahim Khan',
                bio: 'Voluntary blood donor',
                bloodGroup: 'B+',
                totalDonations: 0,
                occupation: 'Software Engineer',
                positionDisplay: 'Software Engineer',
                onPickPhoto: () {},
                onEditBio: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('New Member'), findsWidgets);
      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Rank #0'), findsNothing);
    });

    testWidgets('ProfileHeroCard renders Lifesaver title and Rank when totalDonations >= 5', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileHeroCard(
                displayName: 'Rahim Khan',
                bio: 'Lifesaver donor',
                bloodGroup: 'O+',
                totalDonations: 6,
                rank: 12,
                donorTitle: 'Lifesaver',
                occupation: 'Teacher',
                onPickPhoto: () {},
                onEditBio: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Rank #12'), findsOneWidget);
      expect(find.text('Lifesaver'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
    });

    testWidgets('ProfileRatingXpCard renders clean state when totalDonations is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileRatingXpCard(
              ratingAvg: 5.0,
              ratingCount: 0,
              xp: 0,
              level: 1,
              levelProgress: 0.0,
              tier: 'Active Donor',
              totalDonations: 0,
            ),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Unranked • New Member'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsNWidgets(5));
      expect(find.byIcon(Icons.water_drop_rounded), findsNothing);
    });

    testWidgets('ProfileRatingXpCard renders populated stats when totalDonations > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileRatingXpCard(
              ratingAvg: 4.8,
              ratingCount: 15,
              xp: 450,
              level: 3,
              levelProgress: 0.5,
              tier: 'Lifesaver',
              totalDonations: 5,
              donorTitle: 'Lifesaver',
            ),
          ),
        ),
      );

      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('15 reviews'), findsOneWidget);
      expect(find.text('450'), findsOneWidget);
      expect(find.text('Lvl 3 • Lifesaver'), findsOneWidget);
    });

    testWidgets('ProfileTabsSection displays Not yet issued for donor identifier when totalBagsDonated is 0', (tester) async {
      final mockProfile = ProfileModel(
        id: 42,
        username: 'newbie',
        totalBagsDonated: 0,
        bagsDonated: 0,
        isVerified: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => MockProfileNotifier(mockProfile)),
            profileActivityProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileTabsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Activity Summary tab (index 1)
      await tester.tap(find.text('Activity Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Not yet issued'), findsOneWidget);
      expect(find.text('BP-D000042'), findsNothing);
    });
  });
}

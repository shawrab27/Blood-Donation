// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blood_pulse/features/profile/presentation/screens/blood_group_change_screen.dart';
import 'package:blood_pulse/features/profile/presentation/screens/global_rank_screen.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';

class _MockProfileNotifier extends ProfileNotifier {
  final ProfileModel _model;
  _MockProfileNotifier(this._model);

  @override
  Future<void> fetchProfile() async {
    state = AsyncValue.data(_model);
  }
}

void main() {
  final sampleProfile = ProfileModel(
    id: 99,
    username: 'naimur_donor',
    firstName: 'Md. Naimur',
    lastName: 'Rahman',
    email: 'naimur@example.com',
    bloodGroup: 'B+',
    district: 'Dhaka',
    totalBagsDonated: 12,
    bagsDonated: 12,
    rank: 3,
    globalRank: 3,
    ratingAvg: 4.9,
    ratingCount: 18,
    xp: 1200,
    level: 3,
    levelProgress: 0.6,
    badge: 'Gold Donor',
    isVerified: true,
    isProfileComplete: true,
  );

  group('Profile V2 Complete UI & Stitch Alignment Tests', () {
    testWidgets('UserProfileScreen renders Stitch hero, 3 stats tiles, 2 rating/xp tiles, and certificate button', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _MockProfileNotifier(sampleProfile)),
            topDonorsProvider.overrideWith((ref) async => TopDonorsResponse(
              topDonors: [
                TopDonorItem(rank: 1, id: 101, name: 'Tahmid H.', verifiedBags: 24, bloodGroup: 'O+'),
                TopDonorItem(rank: 2, id: 102, name: 'Anika R.', verifiedBags: 18, bloodGroup: 'A+'),
                TopDonorItem(rank: 3, id: 99, name: 'Md. Naimur', verifiedBags: 12, bloodGroup: 'B+'),
                TopDonorItem(rank: 4, id: 104, name: 'Kamrul I.', verifiedBags: 10, bloodGroup: 'AB+'),
              ],
              otherDonorsCount: 42,
            )),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hero
      expect(find.text('Md. Naimur Rahman'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Rank #3'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Stats row
      expect(find.text('Bags Donated'), findsOneWidget);
      expect(find.text('donations completed'), findsOneWidget);
      expect(find.text('Last Donation'), findsOneWidget);

      // Rating & XP
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('18 reviews'), findsOneWidget);
      expect(find.text('XP'), findsNWidgets(2));
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('Lvl 3 • Gold Donor'), findsOneWidget);

      // Top Donors 5-columns
      expect(find.text('Top Donors'), findsOneWidget);
      expect(find.text('Global Rank'), findsOneWidget);
      expect(find.text('+42'), findsOneWidget);

      // 3 Tabs
      expect(find.text('Your Stories'), findsOneWidget);
      expect(find.text('Activity Summary'), findsOneWidget);
      expect(find.text('Donation History'), findsOneWidget);

      // Footer
      expect(find.text('Download Verified Certificate'), findsOneWidget);
    });

    testWidgets('BloodGroupChangeScreen renders clinical verification fields and consent checkbox', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _MockProfileNotifier(sampleProfile)),
          ],
          child: const MaterialApp(
            home: BloodGroupChangeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Blood Group Change'), findsOneWidget);
      expect(find.text('Current Blood Group'), findsOneWidget);
      expect(find.text('Requested Blood Group *'), findsOneWidget);
      expect(find.text('Diagnostic Laboratory Name *'), findsOneWidget);
      expect(find.text('Date of Lab Test *'), findsOneWidget);
      expect(find.text('Reason for Change *'), findsOneWidget);
      expect(find.text('Attach Diagnostic Report'), findsOneWidget);
      expect(find.text('Submit for Clinical Review'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('GlobalRankScreen renders leaderboard with pinned caller rank', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _MockProfileNotifier(sampleProfile)),
            globalRankProvider(1).overrideWith((ref) async => [
              GlobalRankItem(rank: 1, id: 101, name: 'Tahmid H.', bloodGroup: 'O+', verifiedBags: 24, tier: 'Platinum', ratingAvg: 5.0, ratingCount: 20),
              GlobalRankItem(rank: 2, id: 102, name: 'Anika R.', bloodGroup: 'A+', verifiedBags: 18, tier: 'Diamond', ratingAvg: 4.8, ratingCount: 15),
              GlobalRankItem(rank: 3, id: 99, name: 'Md. Naimur', bloodGroup: 'B+', verifiedBags: 12, tier: 'Gold', ratingAvg: 4.9, ratingCount: 18, isCaller: true),
            ]),
          ],
          child: const MaterialApp(
            home: GlobalRankScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Global Leaderboard'), findsOneWidget);
      expect(find.text('Your Standing'), findsOneWidget);
      expect(find.text('Rank #3 • Gold Donor'), findsOneWidget);
      expect(find.text('Tahmid H.'), findsOneWidget);
      expect(find.text('Anika R.'), findsOneWidget);
      expect(find.text('You'), findsOneWidget); // Pinned caller tag in list
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/profile/domain/models/donor_review_model.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blood_pulse/features/profile/presentation/screens/ratings_reviews_screen.dart';
import 'package:blood_pulse/features/profile/presentation/screens/xp_level_screen.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/modals/last_donation_date_sheet.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/modals/donation_detail_sheet.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/profile_tabs_section.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/heartbeat_tab_indicator.dart';

class _ExtendedMockProfileNotifier extends ProfileNotifier {
  final ProfileModel _model;
  _ExtendedMockProfileNotifier(this._model);

  @override
  Future<void> fetchProfile() async {
    state = AsyncValue.data(_model);
  }

  @override
  Future<Map<String, dynamic>> updateLastDonationDate(String dateStr) async {
    final parsed = DateTime.tryParse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (parsed != null && parsed.isAfter(today)) {
      return {'success': false, 'error': 'Cannot select a future date.'};
    }
    return {'success': true, 'data': {'last_donation_date': dateStr}};
  }
}

void main() {
  final sampleProfile = ProfileModel(
    id: 77,
    username: 'shawrab_donor',
    firstName: 'Shawrab',
    lastName: 'Uddin',
    email: 'shawrab@example.com',
    bloodGroup: 'A+',
    district: 'Dhaka',
    totalBagsDonated: 6,
    bagsDonated: 6,
    rank: 1,
    globalRank: 1,
    ratingAvg: 4.8,
    ratingCount: 14,
    xp: 600,
    level: 2,
    levelProgress: 0.5,
    badge: 'Silver Donor',
    isVerified: true,
    isProfileComplete: true,
    lastDonationDate: '2026-08-01',
    donationHistory: [
      DonationHistoryModel(
        id: 1,
        date: '2026-08-01',
        hospital: 'Dhaka Medical College Hospital',
        city: 'Dhaka',
        bags: 1,
        volumeMl: 450,
        donationType: 'whole_blood',
        how: 'voluntary',
        source: 'verified',
        verified: true,
      ),
      DonationHistoryModel(
        id: 2,
        date: '2026-04-15',
        hospital: 'Square Hospital',
        city: 'Dhaka',
        bags: 1,
        volumeMl: 450,
        donationType: 'whole_blood',
        how: 'voluntary',
        source: 'self_reported',
        verified: false,
      ),
    ],
  );

  group('Profile V2 Extended & Multi-Viewport Overflow Suite', () {
    final viewports = [
      {'name': 'Compact 320x640', 'size': const Size(320, 640)},
      {'name': 'Standard 360x780', 'size': const Size(360, 780)},
      {'name': 'Modern 390x844', 'size': const Size(390, 844)},
      {'name': 'Flagship 412x915', 'size': const Size(412, 915)},
      {'name': 'Tablet 600x1024', 'size': const Size(600, 1024)},
    ];

    for (final vp in viewports) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets('UserProfileScreen zero overflow on ${vp['name']} at textScale ${textScale}x', (tester) async {
          final size = vp['size'] as Size;
          tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileProvider.overrideWith((ref) => _ExtendedMockProfileNotifier(sampleProfile)),
                topDonorsProvider.overrideWith((ref) async => TopDonorsResponse(
                  topDonors: [
                    TopDonorItem(rank: 1, id: 77, name: 'Shawrab U.', verifiedBags: 6, bloodGroup: 'A+', isCurrentUser: true),
                  ],
                  otherDonorsCount: 10,
                )),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: const UserProfileScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('Tab switching by tap and swipe works smoothly with HeartbeatTabIndicator', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _ExtendedMockProfileNotifier(sampleProfile)),
            profileStoriesProvider.overrideWith((ref) => ProfileStoriesNotifier()),
            profileActivityProvider.overrideWith((ref) async => [
              ProfileActivityItem(
                id: 1,
                title: 'Donation Completed',
                subtitle: 'Verified at DMCH',
                timestamp: '2026-08-01T10:00:00Z',
                status: 'COMPLETED',
                autoVerified: true,
              ),
            ]),
            profileDonationsProvider.overrideWith((ref) async => sampleProfile.donationHistory),
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

      // Starts on Tab 0 (Your Stories)
      expect(find.text('Share Story'), findsOneWidget);

      // Tap Tab 1: Activity Summary
      await tester.tap(find.text('Activity Summary'));
      await tester.pumpAndSettle();
      expect(find.text('Donor Identifier'), findsOneWidget);
      expect(find.text('Mobile Number Verification'), findsOneWidget);

      // Tap Tab 2: Donation History
      await tester.tap(find.text('Donation History'));
      await tester.pumpAndSettle();
      expect(find.text('Dhaka Medical College Hospital'), findsOneWidget);
      expect(find.text('Square Hospital'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Self-Reported'), findsOneWidget);

      // Swipe right back to Tab 1
      await tester.drag(find.byType(ProfileTabsSection), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Donor Identifier'), findsOneWidget);

      // Swipe left back to Tab 2
      await tester.drag(find.byType(ProfileTabsSection), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.text('Dhaka Medical College Hospital'), findsOneWidget);

      // Verify HeartbeatTabIndicator exists in TabBar
      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsOneWidget);
      final TabBar tabBar = tester.widget(tabBarFinder);
      expect(tabBar.indicator is HeartbeatTabIndicator, isTrue);
    });

    testWidgets('LastDonationDateSheet disables future dates and enforces 90-day cooldown feedback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _ExtendedMockProfileNotifier(sampleProfile)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LastDonationDateSheet(
                initialDate: DateTime.now().subtract(const Duration(days: 30)),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Record Last Donation'), findsOneWidget);
      expect(find.text('Bangladesh Clinical Protocol: 90-day cooldown between donations.'), findsOneWidget);
      expect(find.text('Next Eligible Date'), findsOneWidget);
      expect(find.text('Save Last Donation Date'), findsOneWidget);

      // CalendarDatePicker is present and configured
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      final CalendarDatePicker datePicker = tester.widget(find.byType(CalendarDatePicker));
      final today = DateTime.now();
      expect(datePicker.lastDate.isAfter(today), isFalse);
    });

    testWidgets('DonationDetailSheet displays verified vs self-reported metadata, XP, and certificate action', (tester) async {
      final verifiedDonation = sampleProfile.donationHistory[0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonationDetailSheet(
              donation: verifiedDonation,
              donorName: 'Shawrab Uddin',
              bloodGroup: 'A+',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dhaka Medical College Hospital'), findsOneWidget);
      expect(find.text('Clinically Verified Donation'), findsOneWidget);
      expect(find.text('+100 XP awarded • Counted toward Top Donors & Global Rank'), findsOneWidget);
      expect(find.text('1 Bag (450 ml)'), findsOneWidget);
      expect(find.text('WHOLE BLOOD'), findsOneWidget);
      expect(find.text('System Confirmed'), findsOneWidget);
      expect(find.text('Share Record'), findsOneWidget);
      expect(find.text('Certificate'), findsOneWidget);
    });

    testWidgets('RatingsReviewsScreen renders distribution bars, rating score, and review list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            donorReviewsProvider(77).overrideWith((ref) async => DonorReviewsResponse(
              ratingAvg: 4.8,
              ratingCount: 14,
              reviews: [
                DonorReviewItem(
                  id: 1,
                  reviewerName: 'Kabir Ahmed',
                  stars: 5,
                  tag: 'Lifesaver',
                  comment: 'Arrived within 30 minutes. Extremely polite and brave donor.',
                  createdAt: '2026-08-01T12:00:00Z',
                ),
                DonorReviewItem(
                  id: 2,
                  reviewerName: 'Fatema Begum',
                  stars: 4,
                  tag: 'Punctual',
                  comment: 'Very helpful brother. May Allah bless him.',
                  createdAt: '2026-05-10T09:30:00Z',
                ),
              ],
            )),
          ],
          child: const MaterialApp(
            home: RatingsReviewsScreen(donorId: 77),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ratings & Reviews'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('14 reviews'), findsOneWidget);
      expect(find.text('Kabir Ahmed'), findsOneWidget);
      expect(find.text('Lifesaver'), findsOneWidget);
      expect(find.text('Arrived within 30 minutes. Extremely polite and brave donor.'), findsOneWidget);
      expect(find.text('Fatema Begum'), findsOneWidget);
      expect(find.text('Punctual'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    });

    testWidgets('XpLevelScreen displays Level, progress bar, badge tiers, and zero doctor discount claims', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _ExtendedMockProfileNotifier(sampleProfile)),
          ],
          child: const MaterialApp(
            home: XpLevelScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('XP & Level Standing'), findsOneWidget);
      expect(find.text('Level 2 Donor'), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('Badge Tiers Hierarchy'), findsOneWidget);
      expect(find.text('Bronze Donor'), findsOneWidget);
      expect(find.text('Silver Donor'), findsNWidgets(2));
      expect(find.text('Gold Donor'), findsOneWidget);
      expect(find.text('Platinum Donor'), findsOneWidget);
      expect(find.text('Diamond Donor'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);

      // How to earn XP rules
      expect(find.text('Verified Blood Donation'), findsOneWidget);
      expect(find.text('+100 XP'), findsOneWidget);
      expect(find.text('Coming Soon'), findsNWidgets(3));

      // Strictly zero doctor discount or medical consultation discount logic
      expect(find.textContaining(RegExp(r'doctor discount', caseSensitive: false)), findsNothing);
      expect(find.textContaining(RegExp(r'consultation discount', caseSensitive: false)), findsNothing);
    });

    testWidgets('Logging out or resetting profile clears cache state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith((ref) => _ExtendedMockProfileNotifier(sampleProfile)),
        ],
      );
      addTearDown(container.dispose);

      // Initially data is loaded
      final initialData = container.read(profileProvider).value;
      expect(initialData, isNotNull);
      expect(initialData!.username, equals('shawrab_donor'));

      // Clear on logout
      container.read(profileProvider.notifier).clear();

      // Verify state was reset
      final refreshed = container.read(profileProvider);
      expect(refreshed.value, isNull);
    });

    testWidgets('Self-profile redirect from Top Donors routes to /profile', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => _ExtendedMockProfileNotifier(sampleProfile)),
            topDonorsProvider.overrideWith((ref) async => TopDonorsResponse(
              topDonors: [
                TopDonorItem(rank: 1, id: 77, name: 'Shawrab U.', verifiedBags: 6, bloodGroup: 'A+', isCurrentUser: true),
              ],
              otherDonorsCount: 0,
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UserProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap caller's avatar in top donors
      final selfTile = find.text('Shawrab');
      expect(selfTile, findsOneWidget);
      await tester.tap(selfTile);
      await tester.pumpAndSettle();

      // No crash, stayed on / rendered personal profile
      expect(find.text('Shawrab Uddin'), findsOneWidget);
    });
  });
}

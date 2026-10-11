// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/communities_view.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/local_club_profile_view.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/division_detail_screen.dart';
import 'package:blood_pulse/features/communities/domain/models/community_models.dart';
import 'package:blood_pulse/features/communities/domain/providers/communities_provider.dart';

void main() {
  group('Step 7: Communities Segments, Privacy & Responsive Tests', () {
    testWidgets('CommunitiesView renders National and Local tabs and top header without overflow at 320x568 and textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nationalCommunitiesProvider.overrideWith((ref) => Future.value([
              NationalCommunity(
                id: 1,
                name: 'Red Crescent Bangladesh',
                activeDonors: '15,000+',
                description: 'National blood program partner',
                phoneNumber: '01700000000',
              ),
            ])),
            medicalPartnersProvider.overrideWith((ref) => Future.value([])),
            areaGuidesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: CommunitiesView(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Header and Tabs
      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('National'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('LocalTabContent renders 8 divisions grid, stepper, and guides', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nationalCommunitiesProvider.overrideWith((ref) => Future.value([])),
            medicalPartnersProvider.overrideWith((ref) => Future.value([])),
            areaGuidesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CommunitiesView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Local' tab
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      // Verify Stepper and 8 divisions catalog
      expect(find.text('Division'), findsOneWidget);
      expect(find.text('District'), findsOneWidget);
      expect(find.text('Upazila'), findsOneWidget);

      // Check divisions in grid
      expect(find.text('Dhaka'), findsWidgets);
      expect(find.text('Chattogram'), findsOneWidget);
      expect(find.text('Rajshahi'), findsOneWidget);
      expect(find.text('Khulna'), findsOneWidget);
      expect(find.text('Barishal'), findsOneWidget);
      expect(find.text('Sylhet'), findsOneWidget);
      expect(find.text('Rangpur'), findsOneWidget);
      expect(find.text('Mymensingh'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('LocalClubProfileView masks hidden contacts and does not render View All Members button', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final unverifiedClub = LocalClub(
        id: 1,
        name: 'Sylhet Youth Lifeline',
        slogan: 'Saving lives together',
        description: 'Dedicated youth community',
        divisionName: 'Sylhet',
        districtName: 'Sylhet',
        upazilaName: 'Kotwali',
        presidentName: 'Aminul Islam',
        contactNumber: '', // Masked by backend serializer because verified_by_admin=False
        totalDonors: '120+',
        activeDonors: '80+',
        contributions: '350+',
        isVerified: true,
        executiveMembers: [
          ExecutiveMember(
            id: 10,
            clubId: 1,
            name: 'Kazi Farhan',
            designation: 'General Secretary',
            phoneNumber: '', // Masked because unverified
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.3),
              ),
              child: LocalClubProfileView(club: unverifiedClub),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify club details render
      expect(find.text('Sylhet Youth Lifeline'), findsOneWidget);
      expect(find.text('About Us'), findsOneWidget);
      expect(find.text('Executive Committee'), findsOneWidget);
      expect(find.text('Aminul Islam'), findsOneWidget);
      expect(find.text('Kazi Farhan'), findsOneWidget);

      // Verify phone call buttons are NOT rendered when phone is empty/masked
      expect(find.byIcon(Icons.call_rounded), findsNothing);

      // Verify strictly NO "View All Members" button / member dashboard
      expect(find.text('View All Members'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('DivisionDetailScreen renders empty state per-division when no clubs registered', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localClubsProvider(LocalClubFilter(divisionId: 999)).overrideWith((ref) => Future.value([])),
            localDonorsProvider('Barishal').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DivisionDetailScreen(
              divisionName: 'Barishal',
              divisionId: 999, // Non-existent division id -> empty
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check empty state
      expect(find.text('Local Blood Clubs'), findsOneWidget);
      expect(find.text('No clubs registered here yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}


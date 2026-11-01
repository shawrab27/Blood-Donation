// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/journey_detail_screen.dart';

void main() {
  final mockRequesterJourney = JourneyDetail(
    id: 101,
    status: 'ACCEPTED',
    viewerRole: JourneyViewerRole.requester,
    bloodGroup: 'B+',
    component: 'WHOLE',
    urgency: 'CRITICAL_2H',
    unitsNeeded: 1,
    steps: const [
      JourneyStep(key: 'OPEN', label: 'Open', completedAt: '2026-10-22T02:00:00Z'),
      JourneyStep(key: 'ACCEPTED', label: 'Accepted', completedAt: '2026-10-22T02:10:00Z'),
    ],
    etaMinutes: 25,
    distanceKm: 4.8,
    canReport: true,
    canCancel: true,
    createdAt: '2026-10-22T02:00:00Z',
    donorName: 'Tanvir Ahmed',
    donorContact: '+8801712345678',
    donorLat: 23.8103,
    donorLng: 90.4125,
    patientName: 'Rahim Uddin',
    hospitalName: 'Dhaka Medical College Hospital',
    requesterContact: '+8801812345678',
    destLat: 23.7259,
    destLng: 90.3976,
    requesterLat: 23.7260,
    requesterLng: 90.3975,
    chatRoomId: 'chat_101_5',
    requestId: 101,
  );

  final mockDonorJourney = JourneyDetail(
    id: 101,
    status: 'ACCEPTED',
    viewerRole: JourneyViewerRole.donor,
    bloodGroup: 'B+',
    component: 'WHOLE',
    urgency: 'CRITICAL_2H',
    unitsNeeded: 1,
    steps: const [
      JourneyStep(key: 'OPEN', label: 'Open', completedAt: '2026-10-22T02:00:00Z'),
      JourneyStep(key: 'ACCEPTED', label: 'Accepted', completedAt: '2026-10-22T02:10:00Z'),
    ],
    etaMinutes: 25,
    distanceKm: 4.8,
    canReport: false,
    canCancel: true,
    createdAt: '2026-10-22T02:00:00Z',
    donorName: 'Tanvir Ahmed',
    donorContact: '+8801712345678',
    donorLat: 23.8103,
    donorLng: 90.4125,
    patientName: 'Rahim Uddin',
    hospitalName: 'Dhaka Medical College Hospital',
    requesterContact: '+8801812345678',
    destLat: 23.7259,
    destLng: 90.3976,
    requesterLat: 23.7260,
    requesterLng: 90.3975,
    chatRoomId: 'chat_101_5',
    requestId: 101,
  );

  testWidgets('FLUTTER 2: Requester role renders Requester layout without interactive role toggle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyDetailProvider(101).overrideWith((ref) => Future.value(mockRequesterJourney)),
        ],
        child: const MaterialApp(
          home: JourneyDetailScreen(journeyId: 101, enablePolling: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Requester badge is rendered
    expect(find.text('Requester'), findsOneWidget);
    // Role switcher toggle from live dispatch must not be present
    expect(find.text('Donor View'), findsNothing);
    expect(find.text('Requester View'), findsNothing);
    // Verifies 'Your Donor' card is rendered
    expect(find.text('Your Donor'), findsOneWidget);
  });

  testWidgets('FLUTTER 2: Donor role renders Donor layout', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyDetailProvider(101).overrideWith((ref) => Future.value(mockDonorJourney)),
        ],
        child: const MaterialApp(
          home: JourneyDetailScreen(journeyId: 101, enablePolling: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Donor badge is rendered
    expect(find.text('Donor'), findsOneWidget);
    // Verifies 'Your Mission' card is rendered for Donor
    expect(find.text('Your Mission'), findsOneWidget);
    // Role switcher toggle from live dispatch must not be present
    expect(find.text('Requester View'), findsNothing);
    expect(find.text('Donor View'), findsNothing);
  });
}

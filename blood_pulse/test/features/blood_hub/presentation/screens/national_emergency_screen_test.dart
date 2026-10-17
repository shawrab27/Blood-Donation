// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/presentation/screens/national_emergency_screen.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/core/access/access_guard.dart';

void main() {
  final sampleRequests = [
    const NationalEmergencyRequestItem(
      id: 101,
      patientName: 'Kazi Farhan',
      bloodGroup: 'O+',
      component: 'WHOLE',
      unitsNeeded: 2,
      unitsReceived: 0,
      unitsPending: 1,
      urgency: 'CRITICAL_2H',
      district: 'Dhaka',
      divisionName: 'Dhaka',
      hospitalName: 'Dhaka Medical College Hospital',
      contactPhoneMasked: '+88017****56',
      status: 'ACTIVE',
      trustBand: 'HIGH',
      trustScore: 85,
    ),
    const NationalEmergencyRequestItem(
      id: 102,
      patientName: 'Nusrat Jahan',
      bloodGroup: 'B+',
      component: 'RBC',
      unitsNeeded: 1,
      unitsReceived: 0,
      unitsPending: 0,
      urgency: 'EMERGENCY_6H',
      district: 'Chattogram',
      divisionName: 'Chattogram',
      hospitalName: 'Chittagong Medical College Hospital',
      contactPhoneMasked: '+88018****89',
      status: 'ACTIVE',
      trustBand: 'MEDIUM',
      trustScore: 70,
    ),
  ];

  Widget buildTestWidget({
    bool isGuest = false,
    List<NationalEmergencyRequestItem> requests = const [],
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        isGuestProvider.overrideWith((ref) => isGuest),
        nationalEmergencyRequestsProvider.overrideWith((ref, filter) async {
          if (filter.bloodGroup != 'All') {
            return requests.where((r) => r.bloodGroup == filter.bloodGroup).toList();
          }
          if (filter.division != 'All') {
            return requests.where((r) => r.divisionName == filter.division).toList();
          }
          return requests;
        }),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
          ),
          child: const NationalEmergencyScreen(),
        ),
      ),
    );
  }

  testWidgets('NationalEmergencyScreen renders verified requests across 64 districts', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(requests: sampleRequests));
    await tester.pumpAndSettle();

    expect(find.text('National Emergency'), findsOneWidget);
    expect(find.text('64 DISTRICTS'), findsOneWidget);
    expect(find.text('Verified Emergency Requests'), findsOneWidget);
    expect(find.text('Kazi Farhan'), findsOneWidget);
    expect(find.text('Dhaka Medical College Hospital'), findsOneWidget);
    expect(find.text('O+'), findsWidgets);
    expect(find.text('I Can Donate'), findsWidgets);
  });

  testWidgets('NationalEmergencyScreen filters requests by blood group', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(requests: sampleRequests));
    await tester.pumpAndSettle();

    // Tap B+ chip
    final bPlusChip = find.widgetWithText(ChoiceChip, 'B+');
    expect(bPlusChip, findsOneWidget);
    await tester.tap(bPlusChip);
    await tester.pumpAndSettle();

    expect(find.text('Nusrat Jahan'), findsOneWidget);
    expect(find.text('Kazi Farhan'), findsNothing);
  });

  testWidgets('NationalEmergencyScreen guest tapping I Can Donate prompts login dialog', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(isGuest: true, requests: sampleRequests));
    await tester.pumpAndSettle();

    final donateButton = find.widgetWithText(ElevatedButton, 'I Can Donate').first;
    await tester.tap(donateButton);
    await tester.pumpAndSettle();

    expect(find.text('Sign In Required'), findsOneWidget);
    expect(find.text('Sign In to Donate'), findsOneWidget);
  });

  testWidgets('NationalEmergencyScreen renders without overflow on 360dp with textScale 1.3', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(requests: sampleRequests, textScale: 1.3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/journey_detail_screen.dart';

void main() {
  const steps = [
    JourneyStep(key: 'OPEN', label: 'Open', completedAt: '2026-10-22T02:00:00Z'),
    JourneyStep(key: 'ACCEPTED', label: 'Accepted', completedAt: '2026-10-22T02:10:00Z'),
  ];

  final donorJourney = JourneyDetail(
    id: 101,
    status: 'ARRIVED',
    viewerRole: JourneyViewerRole.donor,
    bloodGroup: 'B+',
    component: 'WHOLE',
    urgency: 'CRITICAL_2H',
    unitsNeeded: 1,
    steps: steps,
    etaMinutes: 0,
    distanceKm: 0.1,
    canReport: true,
    canCancel: true,
    createdAt: '2026-11-01T10:00:00Z',
    donorName: 'Self (Donor)',
    donorContact: '01811111111',
    donorLat: 23.8103,
    donorLng: 90.4125,
    patientName: 'Patient',
    hospitalName: 'Designated Medical Center',
    requesterContact: '01711111111',
    destLat: 23.8103,
    destLng: 90.4125,
    requesterLat: 23.8103,
    requesterLng: 90.4125,
    canReportMedical: true,
    canReportNoShow: false,
  );

  final requesterJourneyLocked = JourneyDetail(
    id: 102,
    status: 'ACCEPTED',
    viewerRole: JourneyViewerRole.requester,
    bloodGroup: 'O+',
    component: 'WHOLE',
    urgency: 'URGENT_6H',
    unitsNeeded: 1,
    steps: steps,
    etaMinutes: 25,
    distanceKm: 4.8,
    canReport: true,
    canCancel: true,
    createdAt: '2026-11-01T10:00:00Z',
    donorName: 'Karim',
    donorContact: '01722222222',
    donorLat: 23.8103,
    donorLng: 90.4125,
    patientName: 'Patient',
    hospitalName: 'Designated Medical Center',
    requesterContact: '01822222222',
    destLat: 23.8103,
    destLng: 90.4125,
    requesterLat: 23.8103,
    requesterLng: 90.4125,
    canReportMedical: false,
    canReportNoShow: false,
  );

  final requesterJourneyUnlocked = JourneyDetail(
    id: 103,
    status: 'ON_THE_WAY',
    viewerRole: JourneyViewerRole.requester,
    bloodGroup: 'O+',
    component: 'WHOLE',
    urgency: 'URGENT_6H',
    unitsNeeded: 1,
    steps: steps,
    etaMinutes: 25,
    distanceKm: 4.8,
    canReport: true,
    canCancel: true,
    createdAt: '2026-11-01T08:00:00Z',
    donorName: 'Karim',
    donorContact: '01722222222',
    donorLat: 23.8103,
    donorLng: 90.4125,
    patientName: 'Patient',
    hospitalName: 'Designated Medical Center',
    requesterContact: '01822222222',
    destLat: 23.8103,
    destLng: 90.4125,
    requesterLat: 23.8103,
    requesterLng: 90.4125,
    canReportMedical: false,
    canReportNoShow: true,
  );

  testWidgets('FLUTTER 5: Donor sees only medical rejection reasons and no freetext note', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DonationIssueSheet(journey: donorJourney),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report Medical Rejection'), findsOneWidget);
    expect(find.text('Low Hemoglobin'), findsOneWidget);
    expect(find.text('Recent Medication'), findsOneWidget);
    expect(find.text('Vein Access Issue'), findsOneWidget);
    expect(find.text('Other Clinical Reason'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    final submitBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(submitBtn.onPressed, isNotNull);
    expect(find.text('Submit Medical Rejection'), findsOneWidget);
  });

  testWidgets('FLUTTER 5: Requester sees only No-Show and button is disabled when can_report_no_show is false', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DonationIssueSheet(journey: requesterJourneyLocked),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report Donor No-Show'), findsWidgets);
    expect(find.text('Low Hemoglobin'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    final submitBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(submitBtn.onPressed, isNull);
  });

  testWidgets('FLUTTER 5: Requester button is enabled when can_report_no_show is true', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DonationIssueSheet(journey: requesterJourneyUnlocked),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report Donor No-Show'), findsWidgets);
    final submitBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(submitBtn.onPressed, isNotNull);
  });
}

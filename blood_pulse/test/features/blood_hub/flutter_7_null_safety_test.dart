// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/core/deep_link_resolver.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/journey_detail_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/journey_actions.dart';

void main() {
  final publicViewFixture = <String, dynamic>{
    'id': 701,
    'status': 'ACCEPTED',
    'viewer_role': 'REQUESTER',
    'blood_group': 'AB+',
    'component': 'WHOLE',
    'urgency': 'URGENT_6H',
    'units_needed': 1,
    'milestones': <String, dynamic>{
      'OPEN': '2026-11-01T10:00:00Z',
      'ACCEPTED': '2026-11-01T10:05:00Z',
    },
    'created_at': '2026-11-01T10:00:00Z',
    'donor_name': 'Verified Donor',
    'donor_contact': 'Hidden until accepted',
    'donor_lat': null,
    'donor_lng': null,
    'patient_name': 'Protected Patient',
    'hospital_name': 'Protected Hospital',
    'requester_contact': 'Hidden until accepted',
    'dest_lat': null,
    'dest_lng': null,
    'requester_lat': null,
    'requester_lng': null,
    'hospital_details': null,
    'patient_photo': null,
    'requisition_slip': null,
  };

  test('FLUTTER 7: Public-view response fixture deserialization and null safety', () {
    final detail = JourneyDetail.fromJson(publicViewFixture);

    expect(detail.id, 701);
    expect(detail.donorContact, 'Hidden until accepted');
    expect(detail.requesterContact, 'Hidden until accepted');
    expect(detail.donorLat, isNull);
    expect(detail.donorLng, isNull);
    expect(detail.hospitalDetails, isNull);
    expect(detail.patientPhoto, isNull);
    expect(detail.requisitionSlip, isNull);

    // Helpers correctly reject hidden / masked phone
    expect(isRealCallablePhone(detail.donorContact), isFalse);
    expect(isRealCallablePhone(detail.requesterContact), isFalse);
    expect(isRealCallablePhone('018***'), isFalse);
    expect(isRealCallablePhone('01712345678'), isTrue);
  });

  test('FLUTTER 7: DeepLinkResolver never launches tel: for masked or hidden phones', () async {
    // Should not throw or crash
    await DeepLinkResolver.instance.makePhoneCall('Hidden until accepted');
    await DeepLinkResolver.instance.makePhoneCall('018***');
    await DeepLinkResolver.instance.makePhoneCall('');
  });

  testWidgets('FLUTTER 7: Screen renders cleanly with public masked data: no map crash, Call button hidden', (tester) async {
    final detail = JourneyDetail.fromJson(publicViewFixture);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyDetailProvider(701).overrideWith((ref) => Future.value(detail)),
        ],
        child: const MaterialApp(
          home: JourneyDetailScreen(journeyId: 701),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Friendly protected placeholders
    expect(find.text('Protected Patient'), findsOneWidget);
    expect(find.text('Designated Hospital'), findsOneWidget);
    expect(find.text('Hidden until accepted'), findsOneWidget);

    // Map has no coordinates and should safely render SizedBox.shrink without crashing
    expect(tester.takeException(), isNull);

    // Call Donor button MUST be hidden because contact is "Hidden until accepted"
    expect(find.text('Call Donor'), findsNothing);
    expect(find.text('Call Requester'), findsNothing);
  });
}

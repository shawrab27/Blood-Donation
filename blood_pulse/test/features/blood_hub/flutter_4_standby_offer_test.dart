// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/standby_offer_screen.dart';

void main() {
  final offerWithExpiry = StandbyOfferDetail(
    id: 501,
    status: 'PENDING',
    expiresAt: DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
    bloodGroup: 'B+',
    component: 'WHOLE',
    urgency: 'CRITICAL_2H',
    distanceKm: 3.2,
    hospitalName: 'Designated Medical Center',
    unitsNeeded: 1,
    maskedRequester: 'Farhana R. (018***)',
    canAccept: true,
    canDecline: true,
  );

  final offerWithoutExpiry = StandbyOfferDetail(
    id: 502,
    status: 'PENDING',
    expiresAt: '',
    bloodGroup: 'O+',
    component: 'WHOLE',
    urgency: 'URGENT_6H',
    distanceKm: 5.0,
    hospitalName: 'Designated Medical Center',
    unitsNeeded: 2,
    maskedRequester: 'Kamal H. (017***)',
    canAccept: true,
    canDecline: true,
  );

  testWidgets('FLUTTER 4: Countdown timer is rendered only when API provides expiry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          standbyOfferProvider(501).overrideWith((ref) => Future.value(offerWithExpiry)),
        ],
        child: const MaterialApp(
          home: StandbyOfferScreen(offerId: 501),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify countdown timer text exists when expiresAt is present
    expect(find.text('Time remaining to respond'), findsOneWidget);

    // Verify no doctor mock or broken map placeholders
    expect(find.textContaining('Dr.'), findsNothing);
    expect(find.textContaining('Doctor'), findsNothing);
    expect(find.textContaining('REQ-'), findsNothing);
  });

  testWidgets('FLUTTER 4: Countdown timer is NOT rendered when API expiresAt is empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          standbyOfferProvider(502).overrideWith((ref) => Future.value(offerWithoutExpiry)),
        ],
        child: const MaterialApp(
          home: StandbyOfferScreen(offerId: 502),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify countdown timer text is hidden when expiresAt is empty
    expect(find.text('Time remaining to respond'), findsNothing);
  });
}

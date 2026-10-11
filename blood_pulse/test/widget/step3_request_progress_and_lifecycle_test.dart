// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/access/registration_gate_popup.dart';
import 'package:blood_pulse/core/domain/entities/national_emergency.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/donor_tracking_map.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/national_emergency_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/personal_emergency_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/priority_requisition_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/qr_landing_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/report_broker_dialog.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/request_units_progress_card.dart';
import 'package:blood_pulse/features/notifications/presentation/screens/notification_wallpaper_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Step 3: Shared RequestUnitsProgressCard & Lifecycle UI Tests', () {
    testWidgets(
      '1. Renders 0 / 0 / 2 units initial state and PROXY request mode badge',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RequestUnitsProgressCard(
                unitsReceived: 0,
                unitsPending: 0,
                unitsNeeded: 2,
                requestMode: 'PROXY',
              ),
            ),
          ),
        );

        expect(find.text('0 / 0 / 2 units'), findsOneWidget);
        expect(find.text('Received: 0'), findsOneWidget);
        expect(find.text('Pending: 0'), findsOneWidget);
        expect(find.text('Needed: 2'), findsOneWidget);
        expect(
          find.byKey(const Key('request_mode_badge_PROXY')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('request_closed_thank_you_banner')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '2. Renders 0 / 1 / 2 units pending state with Voluntary Only / Charity badge',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RequestUnitsProgressCard(
                unitsReceived: 0,
                unitsPending: 1,
                unitsNeeded: 2,
                requestMode: 'SELF',
                supportStatus: 'VOLUNTARY_ONLY',
              ),
            ),
          ),
        );

        expect(find.text('0 / 1 / 2 units'), findsOneWidget);
        expect(find.text('Voluntary Only / Charity'), findsOneWidget);
        expect(
          find.byKey(const Key('request_mode_badge_SELF')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '3. Renders 2 / 0 / 2 units closed state with "No longer needed — thank you" and EN/BN retry_after banner',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RequestUnitsProgressCard(
                unitsReceived: 2,
                unitsPending: 0,
                unitsNeeded: 2,
                status: 'CLOSED',
                isClosed: true,
                retryAfterSeconds: 45,
              ),
            ),
          ),
        );

        expect(find.text('2 / 0 / 2 units'), findsOneWidget);
        expect(find.text('No longer needed — thank you'), findsOneWidget);
        expect(
          find.byKey(const Key('rate_limit_retry_after_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('45 seconds'), findsOneWidget);
        expect(find.textContaining('45 সেকেন্ড'), findsOneWidget);
      },
    );

    testWidgets(
      '4. NotificationWallpaperOverlay renders shared progress card and Support Status chips',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: NotificationWallpaperOverlay(
                unitsNeeded: 2,
                unitsReceived: 0,
                unitsPending: 1,
                requestMode: 'PROXY',
              ),
            ),
          ),
        );

        expect(find.text('0 / 1 / 2 units'), findsOneWidget);
        expect(find.byKey(const Key('support_chip_can_support')), findsOneWidget);
        expect(
          find.byKey(const Key('support_chip_voluntary_only')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('support_chip_voluntary_only')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('support_status_badge_VOLUNTARY_ONLY')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '5. QRLandingScreen renders closed 2 / 0 / 2 state and disables respond button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: QRLandingScreen(
              requestId: 101,
              initialBloodGroup: 'A+',
              initialHospital: 'Dhaka Medical College Hospital',
              initialUnitsNeeded: 2,
              initialUnitsReceived: 2,
              initialUnitsPending: 0,
              initialRequestMode: 'PROXY',
              initialStatus: 'CLOSED',
              initialIsClosed: true,
              autoFetch: false,
            ),
          ),
        );

        expect(find.text('2 / 0 / 2 units'), findsOneWidget);
        expect(find.text('No longer needed — thank you'), findsOneWidget);
        final respondBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('qr_landing_respond_btn')),
        );
        expect(respondBtn.onPressed, isNull);
      },
    );

    testWidgets(
      '6. ReportBrokerDialog displays privacy guarantee and target type options',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ReportBrokerDialog(requestId: 101),
            ),
          ),
        );

        expect(find.byKey(const Key('report_broker_dialog')), findsOneWidget);
        expect(
          find.textContaining('never exposed to the reported party'),
          findsOneWidget,
        );
        expect(find.text('BROKER'), findsOneWidget);
        expect(find.text('REQUEST'), findsOneWidget);
        expect(find.text('DONOR'), findsOneWidget);
      },
    );

    testWidgets(
      '7. PersonalEmergencyScreen renders RequestUnitsProgressCard and SELF / PROXY request mode selector',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PersonalEmergencyScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RequestUnitsProgressCard), findsOneWidget);
        expect(find.byKey(const Key('mode_chip_proxy')), findsOneWidget);
        expect(find.byKey(const Key('mode_chip_self')), findsOneWidget);
        expect(find.text('For Another Patient (PROXY)'), findsOneWidget);
        expect(find.text('For Myself (SELF)'), findsOneWidget);
      },
    );

    testWidgets(
      '8. DonorTrackingMapScreen renders RequestUnitsProgressCard with received, pending, and needed units',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: DonorTrackingMapScreen(
                  unitsNeeded: 3,
                  unitsReceived: 1,
                  unitsPending: 1,
                  requestMode: 'PROXY',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RequestUnitsProgressCard), findsOneWidget);
        expect(find.text('1 / 1 / 3 units'), findsOneWidget);
        expect(find.byKey(const Key('request_mode_badge_PROXY')), findsOneWidget);
      },
    );

    testWidgets(
      '9. NationalEmergencyScreen renders shared RequestUnitsProgressCard for disaster requisition points',
      (WidgetTester tester) async {
        final mockEvent = NationalEmergencyEvent(
          id: 1,
          titleEn: 'Cyclone Emergency 2026',
          titleBn: 'ঘূর্ণিঝড় জরুরি অবস্থা ২০২৬',
          descriptionEn: 'Emergency units needed at coastal centers',
          descriptionBn: 'উপকূলীয় কেন্দ্রে রক্ত প্রয়োজন',
          isActive: true,
          isVerified: true,
          donationIntervalDays: 90,
          instructionsEn: 'Carry NID and stay hydrated',
          instructionsBn: 'জাতীয় পরিচয়পত্র সঙ্গে রাখুন',
          points: [
            DisasterResponsePoint(
              id: 10,
              name: 'Coxs Bazar Sadar Hospital',
              district: 'Coxs Bazar',
              lat: 21.4272,
              lng: 92.0058,
              isCamp: false,
              targetBags: 10,
              collectedBags: 4,
              status: 'NEEDED',
              urgentBloodGroups: ['O+', 'B+'],
              donorsOnTheWay: 2,
              lastUpdated: '10m ago',
              slots: [],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeNationalEmergencyProvider.overrideWith(
                (ref) => Future.value(mockEvent),
              ),
            ],
            child: const MaterialApp(
              home: NationalEmergencyScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RequestUnitsProgressCard), findsWidgets);
      },
    );

    testWidgets(
      '10. Guest soft wall RegistrationGatePopup appears when an unauthenticated guest attempts stateful actions',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: RegistrationGatePopup(isGuest: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RegistrationGatePopup), findsOneWidget);
        expect(find.textContaining('Complete your registration'), findsOneWidget);
        expect(find.textContaining('রেজিস্ট্রেশন সম্পূর্ণ করুন'), findsOneWidget);
      },
    );
  });
}

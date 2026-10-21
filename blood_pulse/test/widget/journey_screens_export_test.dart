// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/journey_detail_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/standby_offer_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/thank_you_letter_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/donor_tracking_map.dart';
import 'package:blood_pulse/views/chat/chat_screen.dart';

Future<void> _captureAndSave(WidgetTester tester, GlobalKey key, String fileName) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final dir = Directory('../docs/screens');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        final file = File('../docs/screens/$fileName');
        file.writeAsBytesSync(pngBytes);
        // ignore: avoid_print
      print('Saved: docs/screens/$fileName (${pngBytes.length} bytes)');
      }
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
  });

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
      JourneyStep(key: 'ON_THE_WAY', label: 'On Way', completedAt: null),
      JourneyStep(key: 'ARRIVED', label: 'Arrived', completedAt: null),
      JourneyStep(key: 'DONATED', label: 'Donated', completedAt: null),
      JourneyStep(key: 'COMPLETED', label: 'Done', completedAt: null),
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
      JourneyStep(key: 'ON_THE_WAY', label: 'On Way', completedAt: null),
      JourneyStep(key: 'ARRIVED', label: 'Arrived', completedAt: null),
      JourneyStep(key: 'DONATED', label: 'Donated', completedAt: null),
      JourneyStep(key: 'COMPLETED', label: 'Done', completedAt: null),
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

  final mockOffer = StandbyOfferDetail(
    id: 501,
    status: 'PENDING',
    expiresAt: '2026-10-22T04:00:00Z',
    bloodGroup: 'B+',
    component: 'WHOLE',
    urgency: 'CRITICAL_2H',
    distanceKm: 3.2,
    hospitalName: 'Dhaka Medical College Hospital',
    unitsNeeded: 1,
    maskedRequester: 'Farhana R. (018***)',
    canAccept: true,
    canDecline: true,
  );

  testWidgets('Export 1: Request Detail (Requester View)', (WidgetTester tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyDetailProvider(101).overrideWith((ref) => Future.value(mockRequesterJourney)),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const JourneyDetailScreen(journeyId: 101, enablePolling: false),
          ),
        ),
      ),
    );

    await tester.pump();
    await _captureAndSave(tester, key, 'journey_detail_requester.png');
  });

  testWidgets('Export 2: Request Detail (Donor View)', (WidgetTester tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journeyDetailProvider(101).overrideWith((ref) => Future.value(mockDonorJourney)),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const JourneyDetailScreen(journeyId: 101, enablePolling: false),
          ),
        ),
      ),
    );

    await tester.pump();
    await _captureAndSave(tester, key, 'journey_detail_donor.png');
  });

  testWidgets('Export 3: Chat Screen with read-only banner', (WidgetTester tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const ChatScreen(
              chatRoomId: 'chat_demo',
              chatRecipientName: 'Tanvir Ahmed (Donor)',
              bloodGroup: 'B+',
              isClosed: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await _captureAndSave(tester, key, 'chat_screen.png');
  });

  testWidgets('Export 4: Thank You Letter Screen', (WidgetTester tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const ThankYouLetterScreen(
              matchId: 101,
              donorName: 'Tanvir Ahmed',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await _captureAndSave(tester, key, 'thank_you_letter.png');
  });

  testWidgets('Export 5: Standby Offer Screen', (WidgetTester tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          standbyOfferProvider(501).overrideWith((ref) => Future.value(mockOffer)),
        ],
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const StandbyOfferScreen(offerId: 501),
          ),
        ),
      ),
    );

    await tester.pump();
    await _captureAndSave(tester, key, 'standby_offer.png');
  });

  testWidgets('Export 6: Donor Tracking Map Screen', (WidgetTester tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: const DonorTrackingMapScreen(
              requestId: '101',
              matchId: 101,
              patientName: 'Rahim Uddin',
              donorName: 'Tanvir Ahmed',
              bloodGroup: 'B+',
              isDonorView: false,
              enableLiveTracking: false,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await _captureAndSave(tester, key, 'donor_tracking_map.png');
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P-09 FCM Notification Handler & Deep-Linking Tests', () {
    late List<String> routedLocations;
    late GoRouter testRouter;

    Widget createTestApp() {
      routedLocations = [];
      testRouter = GoRouter(
        initialLocation: '/initial',
        routes: [
          GoRoute(
            path: '/initial',
            builder: (context, state) => const Scaffold(body: Text('Initial Screen')),
          ),
          GoRoute(
            path: '/blood-hub',
            builder: (context, state) {
              routedLocations.add('/blood-hub');
              return const Scaffold(body: Text('Blood Hub Screen'));
            },
          ),
          GoRoute(
            path: '/journeys/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              routedLocations.add('/journeys/$id');
              return Scaffold(body: Text('Journey Screen $id'));
            },
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) {
              final extra = state.extra as String? ?? 'default';
              routedLocations.add('/chat?extra=$extra');
              return Scaffold(body: Text('Chat Screen $extra'));
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              routedLocations.add('/profile');
              return const Scaffold(body: Text('Profile Screen'));
            },
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) {
              routedLocations.add('/notifications');
              return const Scaffold(body: Text('Notifications Screen'));
            },
          ),
        ],
      );

      return MaterialApp.router(
        routerConfig: testRouter,
      );
    }

    testWidgets('Send Path 1: BLOOD_EMERGENCY routes to /blood-hub', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'BLOOD_EMERGENCY',
        'request_id': '101',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Blood Hub Screen'), findsOneWidget);
      expect(routedLocations, contains('/blood-hub'));
    });

    testWidgets('Send Path 2: DONOR_ACCEPTED routes to /journeys/:id', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'DONOR_ACCEPTED',
        'acceptance_id': '55',
        'request_id': '101',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Journey Screen 55'), findsOneWidget);
      expect(routedLocations, contains('/journeys/55'));
    });

    testWidgets('Send Path 3: CHAT_MESSAGE routes to /chat with extra chatId', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'CHAT_MESSAGE',
        'chatId': 'acc_88',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Chat Screen acc_88'), findsOneWidget);
      expect(routedLocations, contains('/chat?extra=acc_88'));
    });

    testWidgets('Send Path 4: JOURNEY_UPDATE routes to /journeys/:id', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'JOURNEY_UPDATE',
        'journey_id': '77',
        'status': 'ON_THE_WAY',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Journey Screen 77'), findsOneWidget);
      expect(routedLocations, contains('/journeys/77'));
    });

    testWidgets('Send Path 5: STANDBY_OFFER routes to /blood-hub', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'STANDBY_OFFER',
        'offer_id': '12',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Blood Hub Screen'), findsOneWidget);
      expect(routedLocations, contains('/blood-hub'));
    });

    testWidgets('Send Path 6: REQUEST_CLOSED routes to /blood-hub', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'REQUEST_CLOSED',
        'request_id': '101',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Blood Hub Screen'), findsOneWidget);
      expect(routedLocations, contains('/blood-hub'));
    });

    testWidgets('Send Path 7: DONOR_THANKS routes to /profile', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'DONOR_THANKS',
        'request_id': '101',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Profile Screen'), findsOneWidget);
      expect(routedLocations, contains('/profile'));
    });

    testWidgets('Send Path 8: TEST_PUSH routes to /notifications', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Initial Screen'));
      FcmService.instance.handlePayloadRouting({
        'type': 'TEST_PUSH',
        'source': 'management_command',
      }, context);

      await tester.pumpAndSettle();
      expect(find.text('Notifications Screen'), findsOneWidget);
      expect(routedLocations, contains('/notifications'));
    });
  });
}

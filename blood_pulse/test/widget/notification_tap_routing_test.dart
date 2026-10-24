import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/services/fcm_service.dart';

void main() {
  group('Notification Tap Routing Tests (G1 Matrix)', () {
    late GoRouter testRouter;
    late String currentRoute;

    GoRoute makeRoute(String path) {
      return GoRoute(
        path: path,
        builder: (context, state) {
          currentRoute = path;
          return Scaffold(body: Text('Screen: $path'));
        },
      );
    }

    Widget createTestApp() {
      currentRoute = '/';
      testRouter = GoRouter(
        initialLocation: '/',
        routes: [
          makeRoute('/'),
          makeRoute('/blood-hub'),
          makeRoute('/journeys/:id'),
          makeRoute('/chat'),
          makeRoute('/profile'),
          makeRoute('/communities'),
          makeRoute('/feed'),
          makeRoute('/notifications'),
        ],
      );

      return MaterialApp.router(
        routerConfig: testRouter,
      );
    }

    testWidgets('emergency_request_new routes to /blood-hub', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'emergency_request_new', 'request_id': '101'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /blood-hub'), findsOneWidget);
    });

    testWidgets('request_accepted routes to /journeys/:id', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'request_accepted', 'acceptance_id': '42'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /journeys/:id'), findsOneWidget);
    });

    testWidgets('donor_cancelled routes to /blood-hub', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'donor_cancelled', 'request_id': '101'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /blood-hub'), findsOneWidget);
    });

    testWidgets('chat_message routes to chat screen', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'chat_message', 'chatId': 'chat_88'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /chat'), findsOneWidget);
    });

    testWidgets('donation_confirmed and thanks_letter route to /profile', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'thanks_letter', 'donor_id': '5'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /profile'), findsOneWidget);
    });

    testWidgets('guide_application_status routes to /communities', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'guide_application_status'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /communities'), findsOneWidget);
    });

    testWidgets('post_like and comment route to /feed', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      FcmService.instance.handlePayloadRouting(
        {'type': 'comment', 'post_id': '99'},
        context,
      );
      await tester.pumpAndSettle();
      expect(find.text('Screen: /feed'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/features/assistant/presentation/widgets/pulseai_overlay.dart';
import 'package:blood_pulse/features/assistant/presentation/widgets/heartbeat_icon.dart';
import 'package:blood_pulse/core/providers/pulse_ai_visibility_provider.dart';

void main() {
  testWidgets('PulseAiOverlay FAB popup does not overflow at textScale 1.0 and 1.3', (WidgetTester tester) async {
    for (final textScale in [1.0, 1.3]) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('Home'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pulseAiVisibilityProvider.overrideWith((ref) => PulseAiVisibilityNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                child: PulseAiOverlay(child: child ?? const SizedBox()),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      
      // Tap the FAB to open the popup menu
      final fabFinder = find.byType(HeartbeatIcon);
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Verify the pills are visible
      expect(find.text('Chat with PulseAI'), findsOneWidget);
      expect(find.text('Analyse blood report'), findsOneWidget);
      expect(find.text('Find donors nearby'), findsOneWidget);
      
      // No RenderFlex overflow exception should be caught by FlutterError
      expect(tester.takeException(), isNull);
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/features/assistant/presentation/widgets/pulseai_overlay.dart';
import 'package:blood_pulse/core/app_router.dart';
import 'package:blood_pulse/core/widgets/brand_mark.dart';
import 'package:blood_pulse/core/providers/pulse_ai_visibility_provider.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';

void main() {
  testWidgets('PulseAiOverlay speed-dial does not overflow across responsive sizes at textScale 1.0 & 1.3', (WidgetTester tester) async {
    const testSizes = [
      Size(320, 640),
      Size(360, 800),
      Size(412, 915),
      Size(600, 960),
    ];

    for (final size in testSizes) {
      for (final textScale in [1.0, 1.3]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final router = GoRouter(
          initialLocation: '/feed',
          routes: [
            GoRoute(path: '/feed', builder: (context, state) => const Scaffold(body: Text('Home'))),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pulseAiVisibilityProvider.overrideWith((ref) => PulseAiVisibilityNotifier()),
              appRouterProvider.overrideWithValue(router),
              authProvider.overrideWith(() => AuthNotifier(
                initialState: const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserProfile(
                    fullName: 'Test User',
                    email: 'test@example.com',
                    primaryPhone: '01700000000',
                    age: 25,
                    gender: 'Male',
                    bloodGroup: 'O+',
                    category: 'civilian',
                    categoryDetails: {},
                    neverDonated: true,
                    totalBagsDonated: 0,
                  ),
                ),
              )),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: PulseAiOverlay(child: child ?? const SizedBox()),
                );
              },
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap the BrandMark FAB to open the speed-dial
        final fabFinder = find.byKey(const Key('pulseai_fab_button'));
        expect(fabFinder, findsOneWidget);
        await tester.tap(fabFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify the 4 pills are visible
        expect(find.text('Chat with PulseAI'), findsOneWidget);
        expect(find.text('Analyse blood report'), findsOneWidget);
        expect(find.text('Find donors nearby'), findsOneWidget);
        expect(find.text('Hide PulseAI'), findsOneWidget);

        // Verify no RenderFlex overflow while expanded
        expect(tester.takeException(), isNull);

        // Tap the FAB again to close the speed-dial
        await tester.tap(fabFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify no RenderFlex overflow after closing
        expect(tester.takeException(), isNull);
      }
    }
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:blood_pulse/features/assistant/presentation/widgets/pulseai_overlay.dart';
import 'package:blood_pulse/core/app_router.dart';
import 'package:blood_pulse/core/providers/pulse_ai_visibility_provider.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/journey_detail_screen.dart';

void main() {
  testWidgets('FLUTTER 6: PulseAI FAB is strictly hidden on journey, standby, emergency, and failed sheet', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(
          path: '/feed',
          builder: (context, state) => const Scaffold(body: Text('Feed Tab')),
        ),
        GoRoute(
          path: '/journeys/:id',
          builder: (context, state) => const Scaffold(body: Text('Journey Screen')),
        ),
        GoRoute(
          path: '/standby/:id',
          builder: (context, state) => const Scaffold(body: Text('Standby Screen')),
        ),
        GoRoute(
          path: '/emergency-request',
          builder: (context, state) => const Scaffold(body: Text('Emergency Request Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pulseAiVisibilityProvider.overrideWith((ref) => PulseAiVisibilityNotifier()),
          appRouterProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PulseAiOverlay(child: child ?? const SizedBox()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. On /feed (allowlist): FAB is visible
    final fabFinder = find.byKey(const Key('pulseai_fab_button'));
    expect(fabFinder, findsOneWidget);

    // 2. Navigate to Journey Screen (/journeys/101): FAB is hidden
    router.go('/journeys/101');
    await tester.pumpAndSettle();
    expect(find.text('Journey Screen'), findsOneWidget);
    expect(fabFinder, findsNothing);

    // 3. Navigate to Standby Screen (/standby/501): FAB is hidden
    router.go('/standby/501');
    await tester.pumpAndSettle();
    expect(find.text('Standby Screen'), findsOneWidget);
    expect(fabFinder, findsNothing);

    // 4. Navigate to Emergency Request Screen (/emergency-request): FAB is hidden
    router.go('/emergency-request');
    await tester.pumpAndSettle();
    expect(find.text('Emergency Request Screen'), findsOneWidget);
    expect(fabFinder, findsNothing);
  });

  testWidgets('FLUTTER 6: PulseAI FAB is suppressed when DonationIssueSheet is open', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(
          path: '/feed',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_sheet_btn'),
                  onPressed: () {
                    ref.read(pulseAiSuppressedProvider.notifier).state = true;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const DonationIssueSheet(
                        journey: JourneyDetail(
                          id: 99,
                          status: 'ARRIVED',
                          viewerRole: JourneyViewerRole.donor,
                          bloodGroup: 'A+',
                          component: 'WHOLE',
                          urgency: 'CRITICAL_2H',
                          unitsNeeded: 1,
                          steps: [],
                          etaMinutes: 0,
                          distanceKm: 0.1,
                          canReport: true,
                          canCancel: true,
                          createdAt: '2026-11-01T10:00:00Z',
                          donorName: 'Donor',
                          donorContact: '01811111111',
                          donorLat: 23.8103,
                          donorLng: 90.4125,
                          patientName: 'Patient',
                          hospitalName: 'Hospital',
                          requesterContact: '01711111111',
                          destLat: 23.8103,
                          destLng: 90.4125,
                          requesterLat: 23.8103,
                          requesterLng: 90.4125,
                        ),
                      ),
                    ).whenComplete(() {
                      ref.read(pulseAiSuppressedProvider.notifier).state = false;
                    });
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pulseAiVisibilityProvider.overrideWith((ref) => PulseAiVisibilityNotifier()),
          appRouterProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PulseAiOverlay(child: child ?? const SizedBox()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final fabFinder = find.byKey(const Key('pulseai_fab_button'));
    expect(fabFinder, findsOneWidget);

    // Open sheet
    await tester.tap(find.byKey(const Key('open_sheet_btn')));
    await tester.pumpAndSettle();

    // Sheet is open
    expect(find.text('Report Medical Rejection'), findsOneWidget);
    // PulseAI FAB is suppressed!
    expect(fabFinder, findsNothing);
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:blood_pulse/features/guest/presentation/screens/guest_welcome_screen.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/core/access/access_guard.dart';

void main() {
  group('Anomaly #3: Guest Map Cold Start, Retry & Zero-Fake-Data Tests', () {
    testWidgets('Guest map shows waking up state with countdown on network failure and zero fake pins', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool fetchCalled = false;
      final completer = Completer<Map<String, dynamic>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: MaterialApp(
            home: GuestWelcomeScreen(
              locationResolver: () async => (
                center: const LatLng(23.8103, 90.4125),
                zoom: 12.0,
                statusMessage: 'Live Area',
              ),
              mapDataFetcher: () {
                fetchCalled = true;
                return completer.future;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(fetchCalled, isTrue);

      // Simulate network error / cold-start timeout
      completer.completeError(TimeoutException('Render free-tier cold start timeout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Reassures user that map tiles are cached locally and server is waking up
      expect(find.text('Offline mode — map tiles cached locally'), findsOneWidget);
      expect(find.textContaining('Server waking up'), findsOneWidget);
      expect(find.text('Retry connection'), findsOneWidget);

      // Ensure NO fake donor pins are displayed (O+, A+, B+, etc.)
      expect(find.text('• 4m'), findsNothing);
      expect(find.text('• Univ'), findsNothing);
    });

    testWidgets('Guest map displays coarse clusters correctly when backend returns aggregated cells', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isGuestProvider.overrideWith((ref) => true),
            authProvider.overrideWith(
              () => AuthNotifier(initialState: const AuthState()),
            ),
          ],
          child: MaterialApp(
            home: GuestWelcomeScreen(
              locationResolver: () async => (
                center: const LatLng(23.8103, 90.4125),
                zoom: 12.0,
                statusMessage: 'Live Area',
              ),
              mapDataFetcher: () async => {
                'total_donors': 12,
                'cells': [
                  {
                    'geohash': 'wh0r',
                    'count': 12,
                    'latitude': 23.8100,
                    'longitude': 90.4120,
                    'blood_group': 'A+',
                  },
                ],
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('12 donors in your area'), findsOneWidget);
      expect(find.text('• 12'), findsOneWidget);
    });
  });
}

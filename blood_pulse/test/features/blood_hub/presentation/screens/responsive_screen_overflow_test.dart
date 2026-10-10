// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/features/blood_hub/presentation/screens/blood_hub_landing_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/donor_search_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/poster_generator_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/priority_requisition_screen.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_api_service.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';

class _ResponsiveMockDonorSearchNotifier extends DonorSearchNotifier {
  @override
  Future<DonorSearchPage> build() async {
    return const DonorSearchPage(
      donors: [
        DonorSearchModel(
          id: 1,
          name: 'Altruist Donor',
          bloodGroup: 'O+',
          component: 'WHOLE',
          district: 'Dhaka',
          division: 'Dhaka',
          campus: 'Medical College',
          isVerified: true,
          isEligible: true,
          trustBand: 'HIGH',
          maskedPhone: '+88017****1234',
        ),
      ],
      totalCount: 1,
    );
  }

  @override
  Future<void> loadMore() async {}
}

void main() {
  const viewports = <String, Size>{
    '320x568 (iPhone SE / Compact)': Size(320, 568),
    '360x800 (Standard Android)': Size(360, 800),
    '412x915 (Large / Pixel)': Size(412, 915),
  };

  const textScales = <double>[1.0, 1.3];

  for (final vp in viewports.entries) {
    for (final scale in textScales) {
      testWidgets(
        'BloodHubLandingScreen renders without overflow at ${vp.key} with text scale $scale',
        (tester) async {
          tester.view.physicalSize = vp.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                activeCampaignsProvider.overrideWithValue([]),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vp.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const Scaffold(body: BloodHubLandingScreen()),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'DonorSearchScreen renders without overflow at ${vp.key} with text scale $scale',
        (tester) async {
          tester.view.physicalSize = vp.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                donorSearchNotifierProvider.overrideWith(
                  () => _ResponsiveMockDonorSearchNotifier(),
                ),
                donorMapPinsProvider.overrideWith((ref) => Future.value([])),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vp.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const Scaffold(body: DonorSearchScreen()),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'PosterGeneratorScreen renders without overflow at ${vp.key} with text scale $scale',
        (tester) async {
          tester.view.physicalSize = vp.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vp.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const PosterGeneratorScreen(
                    initialTemplateType: PosterTemplateType.textOnly,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'PriorityBloodRequisitionScreen renders without overflow at ${vp.key} with text scale $scale',
        (tester) async {
          tester.view.physicalSize = vp.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vp.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const PriorityBloodRequisitionScreen(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

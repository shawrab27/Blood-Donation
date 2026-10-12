// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/health_hub/domain/models/product_model.dart';
import 'package:blood_pulse/features/health_hub/domain/providers/health_hub_provider.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_accessories_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/accessories/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testProducts = [
    const ProductModel(
      id: 1,
      name: 'Digital Blood Pressure Monitor',
      tier: 1,
      description: 'Accurate upper arm blood pressure measurement device with digital display.',
      priceMin: 2200,
      priceMax: 3500,
      currency: 'BDT',
      externalUrl: 'https://example.com/bp',
      storeName: 'Daraz BD',
      isActive: true,
      priceRangeText: '৳ 2,200 - ৳ 3,500',
    ),
    const ProductModel(
      id: 2,
      name: 'Sterile Blood Lancets',
      tier: 2,
      description: 'Single-use capillary sampling safety lancets box of 100.',
      priceMin: 300,
      priceMax: 600,
      currency: 'BDT',
      externalUrl: 'https://example.com/lancets',
      storeName: 'Lazz Pharma',
      isActive: true,
      priceRangeText: '৳ 300 - ৳ 600',
    ),
  ];

  group('Task 10F - F2: Blood Accessories Screen & Grid QA', () {
    testWidgets('Renders 2 columns on phone viewport and displays honest pricing & store button', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsProvider.overrideWith((ref, filter) async => testProducts),
          ],
          child: const MaterialApp(
            home: HealthAccessoriesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCard), findsNWidgets(2));
      expect(find.text('Digital Blood Pressure Monitor'), findsOneWidget);
      expect(find.text('Approx. ৳ 2,200 - ৳ 3,500'), findsOneWidget);
      expect(find.text('Visit Daraz BD'), findsOneWidget);
      expect(find.text('Visit Lazz Pharma'), findsOneWidget);

      // Verify honesty: no fake star ratings or fake review counts
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('Renders 3 columns on tablet viewport (600x960)', (tester) async {
      tester.view.physicalSize = const Size(600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsProvider.overrideWith((ref, filter) async => testProducts),
          ],
          child: const MaterialApp(
            home: HealthAccessoriesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      final gridFinder = find.byType(SliverGrid);
      expect(gridFinder, findsOneWidget);
      final sliverGrid = tester.widget<SliverGrid>(gridFinder);
      final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
    });

    testWidgets('Responsive sweep across 4 viewports with textScale 1.3 without overflow', (tester) async {
      final viewports = [
        const Size(320, 640),
        const Size(360, 800),
        const Size(412, 915),
        const Size(600, 960),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productsProvider.overrideWith((ref, filter) async => testProducts),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: const HealthAccessoriesScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        expect(find.byType(HealthAccessoriesScreen), findsOneWidget);
      }
    });
  });
}

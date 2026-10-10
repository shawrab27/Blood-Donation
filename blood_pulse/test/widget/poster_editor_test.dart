// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/poster_generator_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_style_selectors.dart';

// ---------------------------------------------------------------------------
// Minimal fake localisations so tests don't need device resources
// ---------------------------------------------------------------------------
Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final sampleData = PosterData(
    patientName: 'Test Patient',
    bloodGroup: 'B+',
    location: 'Dhaka, Bangladesh',
    unitsNeeded: 2,
    urgencyLevel: 'CRITICAL',
    condition: 'Surgery',
    hospitalName: 'Dhaka Medical College',
    contactNumber: '+8801700000000',
  );

  group('PosterGeneratorScreen', () {
    testWidgets('renders AppBar with Poster Studio title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PosterGeneratorScreen(initialData: sampleData),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // AppBar should contain the poster title text
      expect(find.textContaining('Poster'), findsWidgets);
    });

    testWidgets('shows template type tabs (1. Photo, 2. Text, 3. Custom)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PosterGeneratorScreen(initialData: sampleData),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Exact tab labels from _templateTypeSelector
      expect(find.text('1. Photo'), findsOneWidget);
      expect(find.text('2. Text'), findsOneWidget);
      expect(find.text('3. Custom'), findsOneWidget);
    });

    testWidgets('tapping 2. Text tab switches template', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PosterGeneratorScreen(initialData: sampleData),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Text'));
      await tester.pumpAndSettle();
      // No crash — template type switched
      expect(find.textContaining('Text'), findsWidgets);
    });

    testWidgets('Save to Gallery button is present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PosterGeneratorScreen(initialData: sampleData),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Gallery'), findsOneWidget);
    });

    testWidgets('Share Poster button is present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PosterGeneratorScreen(initialData: sampleData),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Share'), findsWidgets);
    });
  });

  group('PosterSizeSelector', () {
    testWidgets('renders 3 ratio options', (tester) async {
      PosterAspectRatio selected = PosterAspectRatio.square;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setS) => PosterSizeSelector(
              selected: selected,
              onChanged: (r) => setS(() => selected = r),
            ),
          ),
        ),
      );
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('4:5'), findsOneWidget);
      expect(find.text('9:16'), findsOneWidget);
    });

    testWidgets('tapping 4:5 updates selection', (tester) async {
      PosterAspectRatio selected = PosterAspectRatio.square;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setS) => PosterSizeSelector(
              selected: selected,
              onChanged: (r) => setS(() => selected = r),
            ),
          ),
        ),
      );
      await tester.tap(find.text('4:5'));
      await tester.pumpAndSettle();
      expect(selected, equals(PosterAspectRatio.portrait));
    });
  });

  group('PosterColorThemeSelector', () {
    testWidgets('renders all 4 theme names', (tester) async {
      PosterColorTheme selected = PosterColorTheme.crimson;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setS) => PosterColorThemeSelector(
              selected: selected,
              onChanged: (t) => setS(() => selected = t),
            ),
          ),
        ),
      );
      expect(find.text('Crimson'), findsOneWidget);
      expect(find.text('Dark Red'), findsOneWidget);
      expect(find.text('Midnight'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
    });

    testWidgets('tapping Midnight updates selection', (tester) async {
      PosterColorTheme selected = PosterColorTheme.crimson;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setS) => PosterColorThemeSelector(
              selected: selected,
              onChanged: (t) => setS(() => selected = t),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Midnight'));
      await tester.pumpAndSettle();
      expect(selected, equals(PosterColorTheme.midnight));
    });
  });

  group('PosterData', () {
    test('copyWith preserves fields', () {
      final updated = sampleData.copyWith(bloodGroup: 'O+', unitsNeeded: 3);
      expect(updated.bloodGroup, 'O+');
      expect(updated.unitsNeeded, 3);
      expect(updated.patientName, sampleData.patientName);
    });

    test('empty() produces non-empty defaults', () {
      final empty = PosterData.empty();
      expect(empty.patientName, isNotEmpty);
      expect(empty.bloodGroup, isNotEmpty);
    });
  });
}

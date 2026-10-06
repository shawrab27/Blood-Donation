// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/data/datasources/poster_local_datasource.dart';
import 'package:blood_pulse/features/blood_hub/data/repositories/poster_repository_impl.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/poster_generator_screen.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_generator_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final samplePosterData = PosterData(
    patientName: 'Rahim Uddin',
    bloodGroup: 'B+',
    location: 'Dhaka Medical College',
    unitsNeeded: 2,
    urgencyLevel: 'HIGH',
    condition: 'Surgery',
    hospitalName: 'Dhaka Medical College Hospital',
    contactNumber: '+880 1711-209842',
    dateNeeded: 'Today 6:00 PM',
    customHeadline: 'CRITICAL BLOOD NEEDED',
    customMessage: 'Emergency whole blood transfusion needed.',
  );

  group('PosterData Domain & Data Layer Tests', () {
    test('PosterData instantiation and copyWith work correctly', () {
      final data = samplePosterData.copyWith(unitsNeeded: 3, bloodGroup: 'O-');
      expect(data.patientName, 'Rahim Uddin');
      expect(data.bloodGroup, 'O-');
      expect(data.unitsNeeded, 3);
      expect(data.urgencyLevel, 'HIGH');
    });

    test('PosterRepository delegates properly to data source', () async {
      final fakeDataSource = _FakePosterDataSource();
      final repository =
          PosterRepositoryImpl(fakeDataSource);

      final dummyFile = File('test_poster.png');
      final exported = await repository.exportToGallery(dummyFile);
      expect(exported.path, contains('BloodPulse/Posters'));

      await repository.sharePoster(dummyFile, samplePosterData);
      expect(fakeDataSource.shareCalled, isTrue);
    });
  });

  group('PosterGeneratorWidget Widget Tests', () {
    testWidgets('Renders Template 1 (withPhoto) correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterGeneratorWidget(
              data: samplePosterData,
              templateType: PosterTemplateType.withPhoto,
              isBangla: false,
            ),
          ),
        ),
      );

      expect(find.text('URGENT BLOOD NEEDED'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Rahim Uddin'), findsWidgets);
      expect(find.text('Dhaka Medical College Hospital'), findsOneWidget);
    });

    testWidgets('Renders Template 2 (textOnly) correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterGeneratorWidget(
              data: samplePosterData,
              templateType: PosterTemplateType.textOnly,
              isBangla: false,
            ),
          ),
        ),
      );

      expect(find.text('URGENT BLOOD NEEDED'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.textContaining('Rahim Uddin'), findsWidgets);
      expect(find.text('HOSPITAL / LOCATION'), findsOneWidget);
    });

    testWidgets('Renders Template 3 (blank customizable) correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosterGeneratorWidget(
              data: samplePosterData,
              templateType: PosterTemplateType.blank,
              isBangla: false,
            ),
          ),
        ),
      );

      expect(find.text('CRITICAL BLOOD NEEDED'), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('URGENCY: HIGH'), findsOneWidget);
      expect(find.text('Emergency whole blood transfusion needed.'),
          findsOneWidget);
    });

    testWidgets('PosterGeneratorScreen renders and switches templates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PosterGeneratorScreen(
              initialData: samplePosterData,
              initialTemplateType: PosterTemplateType.withPhoto,
            ),
          ),
        ),
      );

      // Verify header and template selector tabs
      expect(find.text('Poster Generator'), findsOneWidget);
      expect(find.text('1. Photo'), findsOneWidget);
      expect(find.text('2. Text'), findsOneWidget);
      expect(find.text('3. Custom'), findsOneWidget);

      // Verify bottom action buttons
      expect(find.text('Save to Gallery'), findsOneWidget);
      expect(find.text('Share Poster'), findsOneWidget);

      // Switch to Template 2
      await tester.tap(find.text('2. Text'));
      await tester.pumpAndSettle();
      expect(find.text('HOSPITAL / LOCATION'), findsOneWidget);

      // Switch to Template 3
      await tester.tap(find.text('3. Custom'));
      await tester.pumpAndSettle();
      expect(find.text('CRITICAL BLOOD NEEDED'), findsOneWidget);
    });
  });
}

class _FakePosterDataSource implements PosterLocalDataSource {
  bool shareCalled = false;

  @override
  Future<File> exportToGallery(File pngFile) async {
    return File('/fake/path/BloodPulse/Posters/poster_123.png');
  }

  @override
  Future<void> sharePoster(
    File pngFile,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  }) async {
    shareCalled = true;
  }
}

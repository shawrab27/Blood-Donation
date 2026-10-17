// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/health_hub/domain/models/health_hub_models.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/ai_report_analysis_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/widgets/ai_report/ai_report_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anomaly #17: Blood Report Analysis & Summary Tests', () {
    testWidgets('AiReportAnalysisScreen renders dual mode selector and toggles to paste input', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiReportAnalysisScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Blood Report Scanner'), findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);
      expect(find.text('Paste CBC Text'), findsOneWidget);
      expect(find.text('Upload Blood Report Photo'), findsOneWidget);

      // Switch to Paste mode
      await tester.tap(find.text('Paste CBC Text'));
      await tester.pumpAndSettle();

      expect(find.text('Analyze CBC Report'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AiReportResultsView renders donor readiness, parameters, and disclaimer without overflow', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleResult = AiReportResult(
        summary: 'Patient hemoglobin is slightly below safe donation threshold.',
        donorReadiness: '⚠️ NOT CURRENTLY ELIGIBLE: Hemoglobin (11.8 g/dL) is below the minimum threshold (12.5 g/dL).',
        disclaimer: '⚠️ Medical Disclaimer: This is an automated preliminary informational analysis and not a formal medical diagnosis.',
        dietaryActionPlan: [
          'Iron-rich foods (spinach, lentils, red meat)',
          'Vitamin C to boost iron absorption'
        ],
        results: [
          TestResultItem(testName: 'Hemoglobin (Hb)', value: '11.8', unit: 'g/dL', referenceRange: '12.5 - 17.5 g/dL', status: 'Low'),
          TestResultItem(testName: 'Platelets', value: '240,000', unit: '/mcL', referenceRange: '150,000 - 450,000 /mcL', status: 'Normal'),
          TestResultItem(testName: 'WBC', value: '7,200', unit: '/mcL', referenceRange: '4,000 - 11,000 /mcL', status: 'Normal'),
          TestResultItem(testName: 'RBC', value: '4.6', unit: 'million/mcL', referenceRange: '4.0 - 5.9 million/mcL', status: 'Normal'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiReportResultsView(result: sampleResult),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Health Summary'), findsOneWidget);
      expect(find.textContaining('NOT CURRENTLY ELIGIBLE'), findsOneWidget);
      expect(find.text('Hemoglobin (Hb)'), findsOneWidget);
      expect(find.text('Platelets'), findsOneWidget);
      expect(find.textContaining('Medical Disclaimer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

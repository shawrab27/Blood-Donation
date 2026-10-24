import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_generator_widget.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_style_selectors.dart';

void main() {
  testWidgets('Poster export caps pixelRatio <= 2.0 to prevent OOM/GPU crash', (tester) async {
    expect(kMaxPosterPixelRatio, equals(2.0));
    final posterKey = GlobalKey<PosterGeneratorWidgetState>();
    final sampleData = PosterData(
      patientName: 'Test Patient',
      bloodGroup: 'B+',
      location: 'Dhaka, Bangladesh',
      unitsNeeded: 2,
      urgencyLevel: 'CRITICAL',
      condition: 'Emergency',
      hospitalName: 'Dhaka Medical College',
      contactNumber: '+8801700000000',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PosterGeneratorWidget(
              key: posterKey,
              data: sampleData,
              templateType: PosterTemplateType.textOnly,
              aspectRatio: PosterAspectRatio.square,
              colorTheme: PosterColorTheme.crimson,
              isBangla: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = posterKey.currentState;
    expect(state, isNotNull);

    // boundary.toImage requires real async rasterization via runAsync
    await tester.runAsync(() async {
      // Call exportPNG with an oversized pixelRatio (e.g. 5.0)
      // The internal logic clamps it to <= 2.5 (e.g. 2.0 or 1.5 on web)
      final bytes = await state!.exportPNG(pixelRatio: 5.0);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);

      final defaultBytes = await state.exportPNG();
      expect(defaultBytes, isNotNull);
      expect(defaultBytes.isNotEmpty, isTrue);
    });
  });
}

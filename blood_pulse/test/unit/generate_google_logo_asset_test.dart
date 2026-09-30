import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/widgets/google_logo.dart';

void main() {
  testWidgets('GoogleLogo widget renders and paints without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: GoogleLogo(size: 48),
          ),
        ),
      ),
    );

    expect(find.byType(GoogleLogo), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('Render GoogleLogo to assets/images/google_logo.png at 512x512', () async {
    const double size = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    const painter = GoogleLogoPainter();
    painter.paint(canvas, const Size(size, size));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    expect(byteData, isNotNull);
    final pngBytes = byteData!.buffer.asUint8List();
    expect(pngBytes.length, greaterThan(100));

    final file = File('assets/images/google_logo.png');
    await file.writeAsBytes(pngBytes);
    expect(await file.exists(), isTrue);
  });
}

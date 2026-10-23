import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';

void main() {
  testWidgets('Create Poster button does not overflow or clip at 320dp width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: Row(
                  children: [
                    Expanded(
                      child: CapsuleButton(
                        label: 'Create Poster',
                        icon: Icons.palette_outlined,
                        isOutlined: true,
                        height: 52,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CapsuleButton(
                        label: 'Confirm Submit',
                        icon: Icons.arrow_forward_rounded,
                        showGlow: true,
                        height: 52,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Create Poster'), findsOneWidget);
    expect(find.text('Confirm Submit'), findsOneWidget);
  });
}

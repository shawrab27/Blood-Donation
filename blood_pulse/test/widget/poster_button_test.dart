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

  testWidgets('Outlined Create Poster button does not overflow or wrap at 320dp width', (tester) async {
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
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFC30121), width: 1.5),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {},
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.palette_outlined, color: Color(0xFFC30121), size: 18),
                              SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Create Poster',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFFC30121),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC30121),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            elevation: 0,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Confirm Submit',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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
    expect(find.widgetWithText(OutlinedButton, 'Create Poster'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Confirm Submit'), findsOneWidget);
  });
}

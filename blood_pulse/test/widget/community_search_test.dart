import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/communities_view.dart';

void main() {
  testWidgets('CommunitiesView renders all 3 community segments with headers', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CommunitiesView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('National Community'), findsOneWidget);
    expect(find.text('Local Community'), findsOneWidget);
    expect(find.text('National Volunteer Networks'), findsOneWidget);
  });
}


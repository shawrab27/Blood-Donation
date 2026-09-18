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

    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('National'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Organizations'), findsOneWidget);
    expect(find.text('Medical Partners'), findsWidgets);
  });
}


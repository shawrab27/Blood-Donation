import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/communities_view.dart';

void main() {
  testWidgets('CommunitiesView renders all 3 community segments with headers', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunitiesView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1. Volunteer Networks'), findsOneWidget);
    expect(find.text('2. Medical Partners & Blood Banks'), findsOneWidget);
    expect(find.text('Badhan'), findsOneWidget);
    expect(find.text('Sandhani'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('3. Personal Contacts & Local Guides'),
      500.0,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('3. Personal Contacts & Local Guides'), findsOneWidget);
  });
}

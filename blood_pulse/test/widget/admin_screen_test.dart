import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/admin/admin_screen.dart';
import 'package:blood_pulse/features/admin/admin_dashboard_screen.dart';

void main() {
  testWidgets('AdminScreen renders harassment panel and queue stats', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Harassment Filter Panel', skipOffstage: false), findsOneWidget);
    expect(find.text('Pending Verifications', skipOffstage: false), findsOneWidget);
    expect(find.text('Flagged Users', skipOffstage: false), findsOneWidget);
    expect(find.text('Action Queue', skipOffstage: false), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen renders access gate when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Access Denied. Admins only.', skipOffstage: false), findsOneWidget);
  });
}

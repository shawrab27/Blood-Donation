// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project â€” unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/auth/presentation/widgets/institution_autocomplete.dart';
import 'package:blood_pulse/services/api_client.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.results = const [],
    this.shouldThrow = false,
  });

  List<Map<String, dynamic>> results;
  bool shouldThrow;
  int callCount = 0;
  String? lastQuery;

  @override
  Future<List<Map<String, dynamic>>> searchInstitutions(String query) async {
    callCount++;
    lastQuery = query;
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return results;
  }
}

void main() {
  final sampleInstitutions = [
    {
      'id': 101,
      'name': 'TEST INSTITUTION 1',
      'institution_type': 'school',
      'eiin': '123456',
      'district_name': 'TEST DISTRICT 1',
    },
    {
      'id': 102,
      'name': 'TEST INSTITUTION 2',
      'institution_type': 'college',
      'eiin': '654321',
      'district_name': 'TEST DISTRICT 2',
    },
  ];

  Widget buildTestWidget({
    required TextEditingController controller,
    required ValueChanged<Map<String, dynamic>?> onSelected,
    required ApiClient apiClient,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: InstitutionAutocomplete(
            controller: controller,
            onSelected: onSelected,
            apiClient: apiClient,
          ),
        ),
      ),
    );
  }

  testWidgets('Debounce works: does not query API immediately on typing', (WidgetTester tester) async {
    final controller = TextEditingController();
    final fakeClient = FakeApiClient(results: sampleInstitutions);

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        onSelected: (_) {},
        apiClient: fakeClient,
      ),
    );


    // Type two characters
    await tester.enterText(find.byType(TextField), 'TE');
    await tester.pump(); // immediate pump

    // Before 350ms debounce duration, API should not have been called
    expect(fakeClient.callCount, 0);

    // Fast-forward past the 350ms debounce
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(fakeClient.callCount, 1);
    expect(fakeClient.lastQuery, 'TE');
  });

  testWidgets('Min 2 chars: does not query API when query length is less than 2', (WidgetTester tester) async {
    final controller = TextEditingController();
    final fakeClient = FakeApiClient(results: sampleInstitutions);

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        onSelected: (_) {},
        apiClient: fakeClient,
      ),
    );

    // Type 1 character
    await tester.enterText(find.byType(TextField), 'T');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(fakeClient.callCount, 0);
  });

  testWidgets('Dropdown displays results with name, district, and type badge', (WidgetTester tester) async {
    final controller = TextEditingController();
    final fakeClient = FakeApiClient(results: sampleInstitutions);

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        onSelected: (_) {},
        apiClient: fakeClient,
      ),
    );

    await tester.enterText(find.byType(TextField), 'TEST');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('TEST INSTITUTION 1'), findsOneWidget);
    expect(find.text('TEST INSTITUTION 2'), findsOneWidget);
    expect(find.text('TEST DISTRICT 1'), findsOneWidget);
    expect(find.text('SCHOOL'), findsOneWidget);
    expect(find.text('COLLEGE'), findsOneWidget);
  });

  testWidgets('Selecting an institution updates controller text and triggers onSelected', (WidgetTester tester) async {
    final controller = TextEditingController();
    final fakeClient = FakeApiClient(results: sampleInstitutions);
    Map<String, dynamic>? selected;

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        onSelected: (val) => selected = val,
        apiClient: fakeClient,
      ),
    );

    await tester.enterText(find.byType(TextField), 'TEST');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Tap the first suggestion
    await tester.tap(find.text('TEST INSTITUTION 1'));
    await tester.pumpAndSettle();

    expect(controller.text, 'TEST INSTITUTION 1');
    expect(selected, isNotNull);
    expect(selected!['id'], 101);
  });

  testWidgets('Fallback works when no results: shows clean message and keeps typed free-text', (WidgetTester tester) async {
    final controller = TextEditingController();
    final fakeClient = FakeApiClient(results: []);
    Map<String, dynamic>? selected;

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        onSelected: (val) => selected = val,
        apiClient: fakeClient,
      ),
    );

    await tester.enterText(find.byType(TextField), 'TEST UNLISTED INSTITUTION');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No institutions found. You can keep what you typed.'), findsOneWidget);
    expect(controller.text, 'TEST UNLISTED INSTITUTION');
    expect(selected, isNull);
  });

  testWidgets('Clear button (X) resets field and clears selected item', (WidgetTester tester) async {
    final controller = TextEditingController();
    final fakeClient = FakeApiClient(results: sampleInstitutions);
    Map<String, dynamic>? selected;

    await tester.pumpWidget(
      buildTestWidget(
        controller: controller,
        onSelected: (val) => selected = val,
        apiClient: fakeClient,
      ),
    );

    await tester.enterText(find.byType(TextField), 'TEST');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Select item
    await tester.tap(find.text('TEST INSTITUTION 1'));
    await tester.pumpAndSettle();
    expect(controller.text, 'TEST INSTITUTION 1');
    expect(selected?['id'], 101);

    // Tap clear button (X)
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(controller.text, '');
    expect(selected, isNull);
  });
}

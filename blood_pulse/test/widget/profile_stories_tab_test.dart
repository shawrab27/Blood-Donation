// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';
import 'package:blood_pulse/features/profile/presentation/widgets/profile_tabs_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockStoriesNotifier extends ProfileStoriesNotifier {
  final AsyncValue<List<ProfileStoryModel>> initialValue;
  int fetchCallCount = 0;

  MockStoriesNotifier(this.initialValue) : super() {
    state = initialValue;
  }

  @override
  Future<void> fetchStories() async {
    fetchCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile #8: Your Stories Tab State & Retry', () {
    testWidgets('renders empty state when there are no stories', (tester) async {
      final mockNotifier = MockStoriesNotifier(const AsyncValue.data([]));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileStoriesProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileTabsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No stories shared yet.'), findsOneWidget);
      expect(find.text('Inspire fellow donors in Bangladesh by sharing your donation journey!'), findsOneWidget);
    });

    testWidgets('renders error state with retry button and calls fetchStories on tap', (tester) async {
      final mockNotifier = MockStoriesNotifier(AsyncValue.error('Network error', StackTrace.empty));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileStoriesProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileTabsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Could not load your stories'), findsOneWidget);
      expect(find.text('Please check your connection and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      final initialCount = mockNotifier.fetchCallCount;
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(mockNotifier.fetchCallCount, initialCount + 1);
    });

    testWidgets('renders stories list with author and reactions', (tester) async {
      final stories = [
        ProfileStoryModel(
          id: 101,
          authorName: 'Karim Rahman',
          location: 'Dhaka',
          content: 'Just completed my 3rd voluntary blood donation at DMCH!',
          likesCount: 12,
          commentsCount: 3,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];

      final mockNotifier = MockStoriesNotifier(AsyncValue.data(stories));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileStoriesProvider.overrideWith((ref) => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileTabsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Karim Rahman'), findsOneWidget);
      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Just completed my 3rd voluntary blood donation at DMCH!'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}

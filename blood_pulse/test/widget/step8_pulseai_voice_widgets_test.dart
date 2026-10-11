// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:blood_pulse/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:blood_pulse/features/assistant/domain/models/assistant_message_model.dart';

void main() {
  testWidgets('AssistantScreen renders mic button and speaker button on messages', (WidgetTester tester) async {
    final messages = [
      AssistantMessage(
        id: 1,
        isUser: true,
        text: 'Who can give me blood?',
      ),
      AssistantMessage(
        id: 2,
        isUser: false,
        text: 'Your blood group is A+. Currently, there are 5 eligible donor(s) registered in Dhaka.',
        language: 'en',
      ),
    ];

    final fakeNotifier = _FakeAssistantNotifier(
      AssistantState(messages: messages, isFirstRun: false),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantProvider.overrideWith((ref) => fakeNotifier),
        ],
        child: const MaterialApp(
          home: AssistantScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify mic button is present in the input row
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);

    // Verify input hint
    expect(find.text("Ask PulseAI or paste lab results..."), findsOneWidget);

    // Verify assistant reply rendered
    expect(find.textContaining('Your blood group is A+'), findsOneWidget);

    // Verify speaker / Listen button is rendered on the assistant message
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.text("Listen"), findsOneWidget);
  });
}

class _FakeAssistantNotifier extends StateNotifier<AssistantState>
    implements AssistantNotifier {
  _FakeAssistantNotifier(super.initial);

  @override
  Future<void> sendMessage(String text, String locale,
      {String? screenContext}) async {}

  @override
  Future<void> sendFeedback(AssistantMessage message, String rating,
      {String? reason, String? note}) async {}

  @override
  Future<void> submitHandoff(
      String subject, String message, String preference) async {}

  @override
  Future<void> saveConsent(bool consent) async {}

  @override
  Future<void> clearChat() async {}
}

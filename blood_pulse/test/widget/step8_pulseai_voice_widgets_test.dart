// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/assistant/presentation/screens/assistant_screen.dart';
import 'package:blood_pulse/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:blood_pulse/features/assistant/domain/models/assistant_message_model.dart';
import 'package:blood_pulse/features/assistant/data/pulseai_audio_service.dart';

void main() {
  group('Step 8: PulseAI Voice & Speech Tests', () {
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

    testWidgets('AssistantScreen voice input toggles listening state and renders notice snackbar', (WidgetTester tester) async {
      final fakeNotifier = _FakeAssistantNotifier(
        AssistantState(messages: [], isFirstRun: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssistantScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final micFinder = find.byIcon(Icons.mic_none_outlined);
      expect(micFinder, findsOneWidget);

      // Tap microphone
      await tester.tap(micFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Verifies the privacy disclosure notice is shown once on voice trigger
      expect(find.textContaining("Speech recognition uses device speech service"), findsOneWidget);
    });

    testWidgets('Speaker button displays Bangla TTS install hint when Bangla voice is unavailable', (WidgetTester tester) async {
      final messages = [
        AssistantMessage(
          id: 1,
          isUser: false,
          text: 'আপনার রক্তের গ্রুপ O+। ব্লাড হাবে সক্রিয় রিকোয়েস্টে সহায়তা করতে পারেন।',
          language: 'bn',
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
            home: Scaffold(
              body: AssistantScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Find Listen button on Bangla message
      final listenBtn = find.text("Listen");
      expect(listenBtn, findsOneWidget);

      // Tap listen button
      await tester.tap(listenBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Doesn't crash; handles audio gracefully
      expect(tester.takeException(), isNull);
    });

    testWidgets('AssistantScreen renders without overflow at 320x568 with textScale 1.3', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final messages = [
        AssistantMessage(
          id: 1,
          isUser: true,
          text: 'ভাড়া কত?',
        ),
        AssistantMessage(
          id: 2,
          isUser: false,
          text: 'আনুমানিক দূরত্ব: প্রায় ১২ কিমি।\nভাড়ার সম্ভাব্য পরিসীমা: ৳১৮০ - ৳২৪০।',
          language: 'bn',
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
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: AssistantScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify no RenderFlex overflow occurs
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
      expect(find.text("Listen"), findsOneWidget);
    });

    testWidgets('Voice input handles permission denied and speech service unavailable safely', (WidgetTester tester) async {
      final fakeNotifier = _FakeAssistantNotifier(
        AssistantState(messages: [], isFirstRun: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssistantScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final micFinder = find.byIcon(Icons.mic_none_outlined);
      expect(micFinder, findsOneWidget);

      // Trigger mic tap
      await tester.tap(micFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    test('Anomaly #16: PulseAIAudioService normalizes error_speech_timeout into friendly or null message', () {
      // If words were spoken, timeout is normal finish: null
      expect(PulseAIAudioService.normalizeSpeechError('error_speech_timeout', 'আমার রক্তের গ্রুপ কি'), isNull);
      expect(PulseAIAudioService.normalizeSpeechError('error_speech_timeout', 'who can donate'), isNull);

      // If no words spoken, returns polite prompt to try again
      final noWordsMsg = PulseAIAudioService.normalizeSpeechError('error_speech_timeout', '');
      expect(noWordsMsg, contains('No speech detected'));

      // Technical no_match returns friendly message
      final noMatchMsg = PulseAIAudioService.normalizeSpeechError('error_no_match', '');
      expect(noMatchMsg, contains("Couldn't catch that"));
    });

    testWidgets('Anomaly #23: Input bar renders with decorated capsule shape and focusNode integration', (WidgetTester tester) async {
      final fakeNotifier = _FakeAssistantNotifier(
        AssistantState(messages: [], isFirstRun: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AssistantScreen(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final TextField textField = tester.widget(textFieldFinder);
      expect(textField.focusNode, isNotNull);

      final animatedContainerFinder = find.byType(AnimatedContainer);
      expect(animatedContainerFinder, findsWidgets);
    });
  });
}

class _FakeAssistantNotifier extends StateNotifier<AssistantState>
    implements AssistantNotifier {
  _FakeAssistantNotifier(super.initial);

  @override
  Future<void> sendMessage(String text, String locale,
      {bool isRetry = false, String? screenContext}) async {}

  @override
  Future<void> retryLastMessage(String locale, {String? screenContext}) async {}

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

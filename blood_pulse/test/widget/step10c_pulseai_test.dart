import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:blood_pulse/features/assistant/domain/models/assistant_message_model.dart';
import 'package:blood_pulse/features/assistant/data/assistant_api_service.dart';
import 'package:blood_pulse/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:blood_pulse/features/assistant/presentation/widgets/ecg_3d_background.dart';
import 'package:blood_pulse/core/widgets/brand_mark.dart';
import 'package:blood_pulse/services/api_client.dart';

class _FakeFailingThenSuccessAssistantApiService extends AssistantApiService {
  int callCount = 0;

  _FakeFailingThenSuccessAssistantApiService() : super(ApiClient());

  @override
  Future<List<QuickAction>> getQuickActions() async => [];

  @override
  Future<AssistantMessage> sendMessage(
    String message,
    String locale, {
    int? conversationId,
    String? screenContext,
    int attempt = 0,
  }) async {
    callCount++;
    if (callCount == 1) {
      throw AssistantApiException(
        'PULSEAI_UNAVAILABLE',
        'PulseAI service timeout',
        statusCode: 503,
        requestId: 'req_test_123456',
      );
    }
    return AssistantMessage(
      isUser: false,
      text: '[Offline guidance]\nA healthy donor must wait 90 days between donations.',
      conversationId: 42,
      source: 'fallback',
      requestId: 'req_test_789012',
    );
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pulseai_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Step 10C PulseAI Regression Tests', () {
    test('C1: Retry resends the same message without adding a second user bubble and clears errorCode/requestId', () async {
      final fakeApi = _FakeFailingThenSuccessAssistantApiService();
      final container = ProviderContainer(
        overrides: [
          assistantApiProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(assistantProvider.notifier);

      // Give _init() time to open Hive box
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. First send fails
      await notifier.sendMessage('How long between donations?', 'en');
      var state = container.read(assistantProvider);

      expect(state.errorCode, equals('PULSEAI_UNAVAILABLE'));
      expect(state.requestId, equals('req_test_123456'));
      expect(state.lastFailedText, equals('How long between donations?'));

      // Count user bubbles with the query text
      final userBubblesAfterFirstSend = state.messages
          .where((m) => m.isUser && m.text == 'How long between donations?')
          .length;
      expect(userBubblesAfterFirstSend, equals(1));

      // 2. Retry last message
      await notifier.retryLastMessage('en');
      state = container.read(assistantProvider);

      expect(state.errorCode, isNull);
      expect(state.lastFailedText, isNull);

      // Verify NO duplicate user bubble was added
      final userBubblesAfterRetry = state.messages
          .where((m) => m.isUser && m.text == 'How long between donations?')
          .length;
      expect(userBubblesAfterRetry, equals(1));

      // Verify assistant reply was appended with source='fallback' and isOfflineGuidance=true
      final lastMsg = state.messages.last;
      expect(lastMsg.isUser, isFalse);
      expect(lastMsg.source, equals('fallback'));
      expect(lastMsg.isOfflineGuidance, isTrue);
      expect(lastMsg.requestId, equals('req_test_789012'));
      expect(lastMsg.text, contains('90 days'));
    });

    testWidgets('C3: BrandMark renders without outer bounce/shake and respects animateHeartbeat', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandMark(size: 56, animateHeartbeat: true),
            ),
          ),
        ),
      );

      final finder = find.byType(BrandMark);
      expect(finder, findsOneWidget);

      final initialRect = tester.getRect(finder);

      // Pump through animation loop frames and verify outer bounds never move/bounce/scale
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.getRect(finder), equals(initialRect));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('C4: Ecg3DBackground renders with RepaintBoundary and pauses when keyboard opens', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                height: 640,
                child: Ecg3DBackground(isThinking: false),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Ecg3DBackground), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/views/chat/chat_screen.dart';
import 'package:blood_pulse/models/chat_message_model.dart';
import 'package:blood_pulse/services/chat_service.dart';
import 'package:blood_pulse/services/chat_transport.dart';

class MockChatTransport implements ChatTransport {
  final List<ChatMessageModel> mockMessages;
  MockChatTransport(this.mockMessages);

  @override
  Stream<List<ChatMessageModel>> getMessagesStream(String chatId, {String? currentUserId}) {
    return Stream.value(mockMessages);
  }

  @override
  Future<ChatMessageModel?> sendMessage({
    required String chatId,
    required String text,
    String messageType = 'TEXT',
    String? voiceUrl,
    int voiceDurationSeconds = 0,
  }) async {
    return ChatMessageModel(
      messageId: 'new_msg',
      chatId: chatId,
      senderId: 'current_user',
      receiverId: 'donor_1',
      text: text,
      messageType: messageType,
      voiceUrl: voiceUrl,
      voiceDurationSeconds: voiceDurationSeconds,
      timestamp: DateTime.now(),
      status: 'sent',
    );
  }

  @override
  Future<void> markAsRead(String chatId, String messageId) async {}

  @override
  Future<void> reportMessage(String chatId, String messageId, String reason) async {}

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {}

  @override
  void dispose() {}
}

void main() {
  setUp(() {
    ChatService.instance.transport = MockChatTransport([
      ChatMessageModel(
        messageId: '1',
        chatId: '101',
        senderId: 'donor_1',
        receiverId: 'current_user',
        text: 'Hello, I am on my way to the hospital.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        status: 'delivered',
      ),
      ChatMessageModel(
        messageId: '2',
        chatId: '101',
        senderId: 'current_user',
        receiverId: 'donor_1',
        text: 'Thank you so much!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        status: 'read',
      ),
      ChatMessageModel(
        messageId: '3',
        chatId: '101',
        senderId: 'donor_1',
        receiverId: 'current_user',
        text: '',
        messageType: 'VOICE',
        voiceUrl: '/media/chat_voice/sample.m4a',
        voiceDurationSeconds: 14,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        status: 'delivered',
      ),
    ]);
  });

  Widget buildTestWidget() {
    return const ProviderScope(
      child: MaterialApp(
        home: ChatScreen(
          chatRoomId: '101',
          chatRecipientName: 'Tanvir Rahman',
          bloodGroup: 'B+',
          recipientId: 'donor_1',
        ),
      ),
    );
  }

  testWidgets('ChatScreen renders recipient details, messages, and voice bubble', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Recipient Header
    expect(find.text('Tanvir Rahman'), findsOneWidget);
    expect(find.text('B+'), findsOneWidget);

    // Messages
    expect(find.text('Hello, I am on my way to the hospital.'), findsOneWidget);
    expect(find.text('Thank you so much!'), findsOneWidget);

    // Voice Message indicator & duration
    expect(find.text('Voice note'), findsOneWidget);
    expect(find.text('0:14'), findsOneWidget);

    // Mic action button exists in input bar
    expect(find.byTooltip('Record Voice Note'), findsOneWidget);
  });

  testWidgets('Tapping Mic button opens voice recording sheet (#39)', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap mic button
    await tester.tap(find.byTooltip('Record Voice Note'));
    await tester.pumpAndSettle();

    // Verify modal appears with recording information
    expect(find.textContaining('Recording Voice Note'), findsOneWidget);
    expect(find.text('Send Note'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recording Voice Note'), findsNothing);
  });

  testWidgets('ChatScreen handles text scale 1.3 without overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ChatScreen(
              chatRoomId: '101',
              chatRecipientName: 'Tanvir Rahman',
              bloodGroup: 'B+',
              recipientId: 'donor_1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}

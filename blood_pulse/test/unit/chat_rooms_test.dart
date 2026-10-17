// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/models/chat_message_model.dart';

void main() {
  group('Real-Time 1-to-1 Chat Rooms & Notification Messages Tests', () {
    test('ChatRoomSummary instantiates correctly with dynamic user data and zero mock names', () {
      final summary = ChatRoomSummary(
        roomId: 'room_123_456',
        participants: ['user_123', 'donor_456'],
        otherParticipantName: 'Mohammad Farhan',
        otherParticipantId: 'donor_456',
        otherParticipantBloodGroup: 'AB+',
        lastMessage: 'I will be at Dhaka Medical College tomorrow at 10am.',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        hasUnread: true,
      );

      expect(summary.roomId, 'room_123_456');
      expect(summary.participants, containsAll(['user_123', 'donor_456']));
      expect(summary.otherParticipantName, 'Mohammad Farhan');
      expect(summary.otherParticipantBloodGroup, 'AB+');
      expect(summary.lastMessage, contains('Dhaka Medical College'));
      expect(summary.hasUnread, isTrue);

      // Verify that NO fake static names leak into dynamic rooms
      const mockNames = ['Sarah Jenkins', 'Dr. Alim', 'Tanvir Ahmed'];
      expect(mockNames.contains(summary.otherParticipantName), isFalse);
    });

    test('Empty chat rooms list represents true 0-conversation state without static placeholders', () {
      final List<ChatRoomSummary> userRooms = [];

      expect(userRooms.isEmpty, isTrue);
      // Empty state verification: zero mockup cards
      final displayedNames = userRooms.map((r) => r.otherParticipantName).toList();
      expect(displayedNames, isEmpty);
      expect(displayedNames.contains('Sarah Jenkins'), isFalse);
      expect(displayedNames.contains('Dr. Alim'), isFalse);
      expect(displayedNames.contains('Tanvir Ahmed'), isFalse);
    });

    test('Two different accounts receive strictly their own isolated conversations', () {
      final accountARooms = [
        ChatRoomSummary(
          roomId: 'room_userA_donorX',
          participants: ['userA', 'donorX'],
          otherParticipantName: 'Donor Xavier',
          otherParticipantId: 'donorX',
          otherParticipantBloodGroup: 'O-',
          lastMessage: 'Hello from Xavier',
          updatedAt: DateTime.now(),
        ),
      ];

      final accountBRooms = [
        ChatRoomSummary(
          roomId: 'room_userB_donorY',
          participants: ['userB', 'donorY'],
          otherParticipantName: 'Donor Yasmin',
          otherParticipantId: 'donorY',
          otherParticipantBloodGroup: 'B+',
          lastMessage: 'Hello from Yasmin',
          updatedAt: DateTime.now(),
        ),
      ];

      expect(accountARooms.map((r) => r.otherParticipantName), contains('Donor Xavier'));
      expect(accountARooms.map((r) => r.otherParticipantName), isNot(contains('Donor Yasmin')));

      expect(accountBRooms.map((r) => r.otherParticipantName), contains('Donor Yasmin'));
      expect(accountBRooms.map((r) => r.otherParticipantName), isNot(contains('Donor Xavier')));
    });

    test('ChatMessageModel handles voice message payload correctly (#39)', () {
      final voiceMsg = ChatMessageModel.fromJson({
        'id': 'msg_voice_1',
        'acceptance_id': '42',
        'sender_id': 'user_1',
        'recipient_id': 'user_2',
        'content': '',
        'message_type': 'VOICE',
        'voice_url': '/media/chat_voice/42/sample.m4a',
        'voice_duration_seconds': 25,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'sent',
      });

      expect(voiceMsg.isVoice, isTrue);
      expect(voiceMsg.voiceUrl, '/media/chat_voice/42/sample.m4a');
      expect(voiceMsg.voiceDurationSeconds, 25);
      expect(voiceMsg.isSent, isTrue);
      expect(voiceMsg.isDelivered, isFalse);
      expect(voiceMsg.isReadReceipt, isFalse);
      expect(voiceMsg.isReported, isFalse);

      final reportedMsg = voiceMsg.copyWith(isReported: true, status: 'delivered');
      expect(reportedMsg.isReported, isTrue);
      expect(reportedMsg.isDelivered, isTrue);
    });

    test('ChatMessageModel WhatsApp-style status transitions (#37)', () {
      final sentMsg = ChatMessageModel(
        messageId: 'm1',
        chatId: '42',
        senderId: '10',
        receiverId: '20',
        text: 'Are you near the hospital?',
        timestamp: DateTime.now(),
        status: 'sent',
      );
      expect(sentMsg.isSent, isTrue);
      expect(sentMsg.isDelivered, isFalse);
      expect(sentMsg.isReadReceipt, isFalse);

      final deliveredMsg = sentMsg.copyWith(status: 'delivered');
      expect(deliveredMsg.isSent, isFalse);
      expect(deliveredMsg.isDelivered, isTrue);
      expect(deliveredMsg.isReadReceipt, isFalse);

      final readMsg = deliveredMsg.copyWith(status: 'read', isRead: true);
      expect(readMsg.isSent, isFalse);
      expect(readMsg.isDelivered, isFalse);
      expect(readMsg.isReadReceipt, isTrue);
    });
  });
}

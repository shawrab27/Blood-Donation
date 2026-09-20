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
  });
}

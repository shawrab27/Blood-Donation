/// ChatMessageModel representing sent & received messages in real-time emergency chats.
class ChatMessageModel {
  const ChatMessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.attachmentUrl,
    required this.timestamp,
    this.isRead = false,
  });

  final String messageId;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final String? attachmentUrl;
  final DateTime timestamp;
  final bool isRead;

  ChatMessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? text,
    String? attachmentUrl,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessageModel(
      messageId:     messageId ?? this.messageId,
      chatId:        chatId ?? this.chatId,
      senderId:      senderId ?? this.senderId,
      receiverId:    receiverId ?? this.receiverId,
      text:          text ?? this.text,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      timestamp:     timestamp ?? this.timestamp,
      isRead:        isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'attachmentUrl': attachmentUrl,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      messageId: map['messageId'] as String,
      chatId: map['chatId'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      text: map['text'] as String,
      attachmentUrl: map['attachmentUrl'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}

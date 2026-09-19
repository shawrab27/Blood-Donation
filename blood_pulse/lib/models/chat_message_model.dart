/// ChatMessageModel representing sent & received messages in real-time emergency chats.
/// Includes WhatsApp-style delivery status ('sent', 'delivered', 'read').
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
    this.status = 'sent',
  });

  final String messageId;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final String? attachmentUrl;
  final DateTime timestamp;
  final bool isRead;
  final String status; // 'sent' | 'delivered' | 'read'

  bool get isSent => status == 'sent';
  bool get isDelivered => status == 'delivered';
  bool get isReadReceipt => status == 'read' || isRead;

  ChatMessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? text,
    String? attachmentUrl,
    DateTime? timestamp,
    bool? isRead,
    String? status,
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
      status:        status ?? this.status,
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
      'status': status,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    final rawIsRead = map['isRead'] as bool? ?? false;
    final rawStatus = map['status'] as String? ?? (rawIsRead ? 'read' : 'sent');
    return ChatMessageModel(
      messageId: map['messageId'] as String,
      chatId: map['chatId'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      text: map['text'] as String,
      attachmentUrl: map['attachmentUrl'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: rawIsRead || rawStatus == 'read',
      status: rawStatus,
    );
  }
}

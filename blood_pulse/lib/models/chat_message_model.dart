// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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
    this.messageType = 'TEXT',
    this.voiceUrl,
    this.voiceDurationSeconds = 0,
    required this.timestamp,
    this.isRead = false,
    this.status = 'sent',
    this.isReported = false,
  });

  final String messageId;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final String? attachmentUrl;
  final String messageType; // 'TEXT' | 'VOICE' | 'IMAGE'
  final String? voiceUrl;
  final int voiceDurationSeconds;
  final DateTime timestamp;
  final bool isRead;
  final String status; // 'sent' | 'delivered' | 'read'
  final bool isReported;

  bool get isSent => status.toLowerCase() == 'sent';
  bool get isDelivered => status.toLowerCase() == 'delivered';
  bool get isReadReceipt => status.toLowerCase() == 'read' || isRead;
  bool get isVoice => messageType == 'VOICE' || (voiceUrl != null && voiceUrl!.isNotEmpty);

  ChatMessageModel copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? text,
    String? attachmentUrl,
    String? messageType,
    String? voiceUrl,
    int? voiceDurationSeconds,
    DateTime? timestamp,
    bool? isRead,
    String? status,
    bool? isReported,
  }) {
    return ChatMessageModel(
      messageId:            messageId ?? this.messageId,
      chatId:               chatId ?? this.chatId,
      senderId:             senderId ?? this.senderId,
      receiverId:           receiverId ?? this.receiverId,
      text:                 text ?? this.text,
      attachmentUrl:        attachmentUrl ?? this.attachmentUrl,
      messageType:          messageType ?? this.messageType,
      voiceUrl:             voiceUrl ?? this.voiceUrl,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      timestamp:            timestamp ?? this.timestamp,
      isRead:               isRead ?? this.isRead,
      status:               status ?? this.status,
      isReported:           isReported ?? this.isReported,
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
      'messageType': messageType,
      'voiceUrl': voiceUrl,
      'voiceDurationSeconds': voiceDurationSeconds,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'status': status,
      'isReported': isReported,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    final rawIsRead = map['isRead'] as bool? ?? false;
    final rawStatus = map['status'] as String? ?? (rawIsRead ? 'read' : 'sent');
    return ChatMessageModel(
      messageId: (map['messageId'] ?? map['id'] ?? '').toString(),
      chatId: (map['chatId'] ?? map['acceptance_id'] ?? '').toString(),
      senderId: (map['senderId'] ?? map['sender_id'] ?? '').toString(),
      receiverId: (map['receiverId'] ?? map['recipient_id'] ?? '').toString(),
      text: (map['text'] ?? map['content'] ?? '') as String,
      attachmentUrl: map['attachmentUrl'] as String?,
      messageType: (map['messageType'] ?? map['message_type'] ?? 'TEXT') as String,
      voiceUrl: (map['voiceUrl'] ?? map['voice_url']) as String?,
      voiceDurationSeconds: (map['voiceDurationSeconds'] ?? map['voice_duration_seconds'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : (map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now()),
      isRead: rawIsRead || rawStatus.toLowerCase() == 'read',
      status: rawStatus.toLowerCase(),
      isReported: (map['isReported'] ?? map['is_reported'] as bool?) ?? false,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel.fromMap(json);
}

/// Summary of a real-time conversation room between two users in Firestore.
class ChatRoomSummary {
  final String roomId;
  final List<String> participants;
  final String otherParticipantName;
  final String otherParticipantId;
  final String otherParticipantBloodGroup;
  final String lastMessage;
  final DateTime updatedAt;
  final bool hasUnread;

  const ChatRoomSummary({
    required this.roomId,
    required this.participants,
    required this.otherParticipantName,
    required this.otherParticipantId,
    this.otherParticipantBloodGroup = 'O+',
    required this.lastMessage,
    required this.updatedAt,
    this.hasUnread = false,
  });
}

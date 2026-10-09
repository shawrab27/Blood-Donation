// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import 'encryption_service.dart';

abstract final class ChatFields {
  static const String messageId = 'messageId';
  static const String chatId = 'chatId';
  static const String senderId = 'senderId';
  static const String receiverId = 'receiverId';
  static const String text = 'text';
  static const String attachmentUrl = 'attachmentUrl';
  static const String timestamp = 'timestamp';
  static const String isRead = 'isRead';
  static const String status = 'status';
  static const String encryptedAesKey = 'encryptedAesKey';
  static const String ciphertext = 'ciphertext';
  static const String iv = 'iv';
  static const String authTag = 'authTag';
}

/// Helper for mapping, decoding and decrypting Firestore chat messages and rooms.
class ChatMessageCodec {
  const ChatMessageCodec._();

  /// Decodes and decrypts a raw Firestore document into a [ChatMessageModel].
  static Future<ChatMessageModel> decodeDocument(Map<String, dynamic> data) async {
    final messageId = data[ChatFields.messageId] as String? ?? '';
    final chatId = data[ChatFields.chatId] as String? ?? '';
    final senderId = data[ChatFields.senderId] as String? ?? '';
    final receiverId = data[ChatFields.receiverId] as String? ?? '';
    final attachmentUrl = data[ChatFields.attachmentUrl] as String?;
    final isRead = data[ChatFields.isRead] as bool? ?? false;
    final status = data[ChatFields.status] as String? ?? (isRead ? 'read' : 'sent');
    final Timestamp? ts = data[ChatFields.timestamp] as Timestamp?;
    final timestamp = ts?.toDate() ?? DateTime.now();

    String text;
    final encAesKey = data[ChatFields.encryptedAesKey] as String?;
    if (encAesKey != null && encAesKey.isNotEmpty) {
      try {
        final payload = EncryptedMessagePayload.fromMap(data);
        text = await EncryptionService.instance.decrypt(payload) ?? '[Decryption failed]';
      } catch (e) {
        text = '[Decryption error]';
      }
    } else {
      text = data[ChatFields.text] as String? ?? '';
    }

    return ChatMessageModel(
      messageId: messageId,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      attachmentUrl: attachmentUrl,
      timestamp: timestamp,
      isRead: isRead || status == 'read',
      status: status,
    );
  }

  /// Parses a `chat_rooms` document snapshot into a [ChatRoomSummary].
  static ChatRoomSummary mapRoomDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data();
    final roomId = doc.id;
    final participants = List<String>.from(data['participants'] as List? ?? []);
    final otherId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    String otherName = '';
    if (otherId.isNotEmpty && data['userName_$otherId'] != null) {
      otherName = data['userName_$otherId'].toString();
    }
    if (otherName.isEmpty && data['recipientName'] != null) {
      otherName = data['recipientName'].toString();
    }
    if (otherName.isEmpty) {
      otherName = otherId.isNotEmpty ? otherId : 'Blood Donor / Requester';
    }

    final bloodGroup = data['bloodGroup'] as String? ?? 'O+';
    final lastMsg = data['lastMessage'] as String? ?? '';
    final lastReceiverId = data['lastReceiverId'] as String? ?? '';
    final isRead = data['isRead'] as bool? ?? true;
    final hasUnread = (lastReceiverId == currentUserId) && !isRead;

    final Timestamp? ts = data['lastMessageTimestamp'] as Timestamp? ??
        data['updatedAt'] as Timestamp?;
    final updatedAt = ts?.toDate() ?? DateTime.now();

    return ChatRoomSummary(
      roomId: roomId,
      participants: participants,
      otherParticipantName: otherName,
      otherParticipantId: otherId,
      otherParticipantBloodGroup: bloodGroup,
      lastMessage: lastMsg.isNotEmpty ? lastMsg : 'Conversation active',
      updatedAt: updatedAt,
      hasUnread: hasUnread,
    );
  }

  /// Batch updates unread messages to read status for [currentUserId].
  static void batchMarkAsRead(
    FirebaseFirestore? db,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String currentUserId,
  ) {
    if (db == null) return;
    final unread = snapshot.docs.where((doc) {
      final data = doc.data();
      final isRead = data[ChatFields.isRead] as bool? ?? false;
      final status = data[ChatFields.status] as String? ?? '';
      return data[ChatFields.receiverId] == currentUserId && (!isRead || status != 'read');
    }).toList();

    if (unread.isEmpty) return;
    final batch = db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {ChatFields.isRead: true, ChatFields.status: 'read'});
    }
    batch.commit().catchError((Object e) {
      // Ignored in fire-and-forget read status sync.
    });
  }

  /// Marks unread messages addressed to [currentUserId] as 'delivered'.
  static Future<void> markDelivered(
    FirebaseFirestore? db,
    CollectionReference<Map<String, dynamic>>? roomMessagesRef,
    String currentUserId,
  ) async {
    if (db == null || roomMessagesRef == null) return;
    try {
      final snapshot = await roomMessagesRef
          .where(ChatFields.receiverId, isEqualTo: currentUserId)
          .where(ChatFields.status, isEqualTo: 'sent')
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {ChatFields.status: 'delivered'});
      }
      await batch.commit();
    } catch (_) {}
  }
}

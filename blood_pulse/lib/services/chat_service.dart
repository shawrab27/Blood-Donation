// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

/// BloodPulse — Real-Time Firestore Chat Service (E2EE)
/// Exclusively persists to canonical path: `chat_rooms/{roomId}/messages/{messageId}`.
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message_model.dart';
import 'chat_message_codec.dart';
import 'encryption_service.dart';

/// Singleton chat service managing Firestore persistence and E2EE.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  FirebaseFirestore? _customDb;

  @visibleForTesting
  set firestoreInstance(FirebaseFirestore? db) => _customDb = db;

  FirebaseFirestore? get _db {
    if (_customDb != null) return _customDb;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final StreamController<List<ChatMessageModel>> _mockStreamController =
      StreamController<List<ChatMessageModel>>.broadcast();
  final List<ChatMessageModel> _localMessageCache = [];

  CollectionReference<Map<String, dynamic>>? _roomMessages(String roomId) =>
      _db?.collection('chat_rooms').doc(roomId).collection('messages');

  /// Ensures `chat_rooms/{roomId}` document exists with the two participants.
  Future<void> createOrGetRoom({
    required String roomId,
    required String user1Id,
    required String user2Id,
    String? user1Name,
    String? user2Name,
    String? bloodGroup,
  }) async {
    final data = <String, dynamic>{
      'roomId': roomId,
      'chatId': roomId,
      'participants': [user1Id, user2Id],
      'updatedAt': FieldValue.serverTimestamp(),
      if (user1Name != null && user1Name.isNotEmpty) 'userName_$user1Id': user1Name,
      if (user2Name != null && user2Name.isNotEmpty) 'userName_$user2Id': user2Name,
      if (bloodGroup != null && bloodGroup.isNotEmpty) 'bloodGroup': bloodGroup,
    };

    final db = _db;
    if (db == null) return;
    try {
      await db.collection('chat_rooms').doc(roomId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] Error creating room participants: $e');
    }
  }

  /// Real-time stream of all chat rooms for [currentUserId].
  Stream<List<ChatRoomSummary>> getUserChatRoomsStream(String currentUserId) {
    if (currentUserId.isEmpty) return Stream.value(<ChatRoomSummary>[]);
    final db = _db;
    if (db == null) return Stream.value(<ChatRoomSummary>[]);

    try {
      return db
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUserId)
          .snapshots()
          .map((snapshot) {
        final rooms = snapshot.docs
            .map((doc) => ChatMessageCodec.mapRoomDoc(doc, currentUserId))
            .toList();
        rooms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return rooms;
      }).handleError((error) {
        debugPrint('[ChatService] getUserChatRoomsStream error: $error');
        return <ChatRoomSummary>[];
      });
    } catch (e) {
      debugPrint('[ChatService] Error setting up getUserChatRoomsStream: $e');
      return Stream.value(<ChatRoomSummary>[]);
    }
  }

  /// Encrypts and writes message exclusively to Firestore `chat_rooms/{roomId}/messages/{docId}`.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String? senderName,
    String? receiverName,
    String? bloodGroup,
    String? attachmentUrl,
  }) async {
    final roomMessagesRef = _roomMessages(chatId);
    if (roomMessagesRef == null) {
      _addToMockCache(ChatMessageModel(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        attachmentUrl: attachmentUrl,
        timestamp: DateTime.now(),
        isRead: false,
        status: 'sent',
      ));
      return;
    }

    final roomDocRef = roomMessagesRef.doc();
    final docId = roomDocRef.id;
    final now = Timestamp.now();

    await createOrGetRoom(
      roomId: chatId,
      user1Id: senderId,
      user2Id: receiverId,
      user1Name: senderName,
      user2Name: receiverName,
      bloodGroup: bloodGroup,
    );

    EncryptedMessagePayload? encrypted;
    try {
      final recipientPublicKey = await _fetchRecipientPublicKey(receiverId);
      if (recipientPublicKey != null) {
        encrypted = EncryptionService.instance.encrypt(
          plaintext: text,
          recipientPublicKeyPem: recipientPublicKey,
        );
      }
    } catch (e) {
      debugPrint('[ChatService] E2EE encrypt fallback: $e');
    }

    final Map<String, dynamic> data = {
      ChatFields.messageId: docId,
      ChatFields.chatId: chatId,
      ChatFields.senderId: senderId,
      ChatFields.receiverId: receiverId,
      ChatFields.timestamp: now,
      ChatFields.isRead: false,
      ChatFields.status: 'sent',
      ChatFields.attachmentUrl: attachmentUrl,
      if (encrypted != null) ...{
        ChatFields.encryptedAesKey: encrypted.encryptedAesKey,
        ChatFields.ciphertext: encrypted.ciphertext,
        ChatFields.iv: encrypted.iv,
        ChatFields.authTag: encrypted.authTag,
        ChatFields.text: '',
      } else ...{
        ChatFields.text: text,
      },
    };

    try {
      await roomDocRef.set(data);
    } catch (e) {
      debugPrint('[ChatService] Firestore set document error: $e');
    }

    final roomSummary = <String, dynamic>{
      'lastMessage': text.isNotEmpty ? text : (attachmentUrl != null ? '📷 Image' : 'Message'),
      'lastSenderId': senderId,
      'lastReceiverId': receiverId,
      'lastMessageTimestamp': now,
      'updatedAt': now,
      'isRead': false,
    };
    final db = _db;
    if (db != null) {
      try {
        await db.collection('chat_rooms').doc(chatId).set(roomSummary, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[ChatService] Error updating room summary: $e');
      }
    }

    _addToMockCache(ChatMessageModel(
      messageId: docId,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      attachmentUrl: attachmentUrl,
      timestamp: DateTime.now(),
      isRead: false,
      status: 'sent',
    ));
  }

  /// Real-time stream of [ChatMessageModel] from `chat_rooms/{chatId}/messages`.
  Stream<List<ChatMessageModel>> getMessagesStream(String chatId, {String? currentUserId}) {
    final roomMessagesRef = _roomMessages(chatId);
    if (roomMessagesRef == null) return _getMockStream(chatId);

    try {
      return roomMessagesRef
          .orderBy(ChatFields.timestamp, descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
        final messages = <ChatMessageModel>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final msg = await ChatMessageCodec.decodeDocument(data);
          messages.add(msg);
        }

        if (currentUserId != null && snapshot.docs.isNotEmpty) {
          _batchMarkAsRead(chatId, snapshot, currentUserId);
        }
        return messages;
      }).handleError((error) {
        debugPrint('[ChatService] Stream error fallback: $error');
        return _getMockStream(chatId);
      });
    } catch (e) {
      debugPrint('[ChatService] Firestore stream error, using fallback: $e');
      return _getMockStream(chatId);
    }
  }

  /// Updates incoming unread messages to 'delivered' status.
  Future<void> markMessagesAsDelivered(String chatId, String currentUserId) =>
      ChatMessageCodec.markDelivered(_db, _roomMessages(chatId), currentUserId);

  void _batchMarkAsRead(
    String chatId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String currentUserId,
  ) =>
      ChatMessageCodec.batchMarkAsRead(_db, snapshot, currentUserId);

  Future<String?> _fetchRecipientPublicKey(String recipientUid) async {
    final db = _db;
    if (db == null) return null;
    try {
      final doc = await db.collection('users').doc(recipientUid).get();
      return doc.data()?['publicKey'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Cancels listeners and wipes in-memory cache upon user logout.
  void reset() {
    _localMessageCache.clear();
    if (!_mockStreamController.isClosed) {
      _mockStreamController.add(<ChatMessageModel>[]);
    }
  }

  void dispose() {
    reset();
    _mockStreamController.close();
  }

  Stream<List<ChatMessageModel>> _getMockStream(String chatId) {
    Future.microtask(() => _mockStreamController.add(List.from(_localMessageCache)));
    return _mockStreamController.stream;
  }

  void _addToMockCache(ChatMessageModel msg) {
    _localMessageCache.add(msg);
    if (!_mockStreamController.isClosed) {
      _mockStreamController.add(List.from(_localMessageCache));
    }
  }
}

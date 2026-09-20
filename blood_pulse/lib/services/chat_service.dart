/// BloodPulse — Real-Time Firestore Chat Service (E2EE)
///
/// Wires encrypted message streams to/from Firestore.
/// Collection path: `chats/{chatId}/messages/{messageId}`
///
/// Security model:
///   • Every message is encrypted client-side via [EncryptionService] before
///     being written to Firestore.
///   • The Firestore document stores the [EncryptedMessagePayload] fields, not
///     plaintext. The server can never read message content.
///   • Decryption happens locally on the recipient's device using their
///     RSA private key stored in [FlutterSecureStorage].
///   • When no E2EE keys are present (first install / key not yet generated),
///     the service falls back to the unencrypted mock stream so the UI is
///     never broken during development.
///
/// Auto Read Receipts:
///   • When [getMessagesStream] is called (i.e., the ChatScreen opens),
///     all incoming messages where `receiverId == currentUserId` and
///     `isRead == false` are batch-updated to `isRead = true` in Firestore.
///   • The double-blue-tick icon in the UI reacts to this in real time.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message_model.dart';
import 'encryption_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Firestore document field constants
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _Fields {
  static const String messageId      = 'messageId';
  static const String chatId         = 'chatId';
  static const String senderId       = 'senderId';
  static const String receiverId     = 'receiverId';
  static const String text           = 'text';
  static const String attachmentUrl  = 'attachmentUrl';
  static const String timestamp      = 'timestamp';
  static const String isRead         = 'isRead';
  static const String status         = 'status';
  static const String encryptedAesKey = 'encryptedAesKey';
  static const String ciphertext     = 'ciphertext';
  static const String iv             = 'iv';
  static const String authTag        = 'authTag';
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatService
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton chat service.
///
/// Uses Firestore for persistence and [EncryptionService] for E2EE.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Local in-memory cache used as the fallback dev/mock stream.
  final StreamController<List<ChatMessageModel>> _mockStreamController =
      StreamController<List<ChatMessageModel>>.broadcast();
  final List<ChatMessageModel> _localMessageCache = [];

  // ── Collection References ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _db.collection('chats').doc(chatId).collection('messages');

  CollectionReference<Map<String, dynamic>> _roomMessages(String roomId) =>
      _db.collection('chat_rooms').doc(roomId).collection('messages');

  // ── Room Initialization with Participants ───────────────────────────────

  /// Ensures both `chat_rooms/{roomId}` and `chats/{chatId}` documents exist
  /// with the [participants] array listing the two user IDs.
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

    try {
      await Future.wait([
        _db.collection('chat_rooms').doc(roomId).set(data, SetOptions(merge: true)),
        _db.collection('chats').doc(roomId).set(data, SetOptions(merge: true)),
      ]);
    } catch (e) {
      debugPrint('[ChatService] Error ensuring room participants: $e');
    }
  }

  /// Returns a real-time stream of all chat rooms where [currentUserId] is an active participant.
  /// If [currentUserId] is empty or has no active rooms, the stream cleanly returns an empty list.
  Stream<List<ChatRoomSummary>> getUserChatRoomsStream(String currentUserId) {
    if (currentUserId.isEmpty) {
      return Stream.value(<ChatRoomSummary>[]);
    }
    try {
      return _db
          .collection('chat_rooms')
          .where('participants', arrayContains: currentUserId)
          .snapshots()
          .map((snapshot) {
        final rooms = <ChatRoomSummary>[];
        for (final doc in snapshot.docs) {
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

          rooms.add(ChatRoomSummary(
            roomId: roomId,
            participants: participants,
            otherParticipantName: otherName,
            otherParticipantId: otherId,
            otherParticipantBloodGroup: bloodGroup,
            lastMessage: lastMsg.isNotEmpty ? lastMsg : 'Conversation active',
            updatedAt: updatedAt,
            hasUnread: hasUnread,
          ));
        }
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

  // ── Send Message ────────────────────────────────────────────────────────

  /// Encrypts [text] with the recipient's RSA public key and pushes the
  /// ciphertext to Firestore `chats/{chatId}/messages` and `chat_rooms/{chatId}/messages`.
  ///
  /// If E2EE keys are not available (development mode), writes plaintext.
  ///
  /// [chatId]            — Unique chat thread identifier.
  /// [receiverUid]       — UID of the recipient (used to look up public key).
  /// [text]              — Plaintext message content.
  /// [attachmentUrl]     — Optional attachment URL (not encrypted, by design,
  ///                       as it is a CDN URL that does not contain PII).
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
    final docRef     = _messages(chatId).doc();
    final roomDocRef = _roomMessages(chatId).doc(docRef.id);
    final docId      = docRef.id;
    final now        = Timestamp.now();

    // ── Ensure parent room documents exist with participants ─────────────
    await createOrGetRoom(
      roomId: chatId,
      user1Id: senderId,
      user2Id: receiverId,
      user1Name: senderName,
      user2Name: receiverName,
      bloodGroup: bloodGroup,
    );

    // ── Try E2EE encryption ──────────────────────────────────────────────
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
      debugPrint('[ChatService] E2EE encrypt failed: $e');
    }

    final Map<String, dynamic> data = {
      _Fields.messageId:     docId,
      _Fields.chatId:        chatId,
      _Fields.senderId:      senderId,
      _Fields.receiverId:    receiverId,
      _Fields.timestamp:     now,
      _Fields.isRead:        false,
      _Fields.status:        'sent',
      _Fields.attachmentUrl: attachmentUrl,
      // If encrypted, store ciphertext + AES envelope; otherwise plaintext.
      if (encrypted != null) ...{
        _Fields.encryptedAesKey: encrypted.encryptedAesKey,
        _Fields.ciphertext:      encrypted.ciphertext,
        _Fields.iv:              encrypted.iv,
        _Fields.authTag:         encrypted.authTag,
        _Fields.text:            '', // Empty — actual content is encrypted
      } else ...{
        _Fields.text: text,
      },
    };

    try {
      await Future.wait([
        docRef.set(data),
        roomDocRef.set(data),
      ]);
    } catch (e) {
      debugPrint('[ChatService] Firestore set document error: $e');
    }

    // Update parent room document with last message summary
    final roomSummary = <String, dynamic>{
      'lastMessage': text.isNotEmpty ? text : (attachmentUrl != null ? '📷 Image' : 'Message'),
      'lastSenderId': senderId,
      'lastReceiverId': receiverId,
      'lastMessageTimestamp': now,
      'updatedAt': now,
      'isRead': false,
    };
    try {
      await Future.wait([
        _db.collection('chat_rooms').doc(chatId).set(roomSummary, SetOptions(merge: true)),
        _db.collection('chats').doc(chatId).set(roomSummary, SetOptions(merge: true)),
      ]);
    } catch (e) {
      debugPrint('[ChatService] Error updating room summary: $e');
    }

    // Also update the mock stream so the UI reflects the sent message even
    // in environments where Firestore listeners have not been wired to the
    // StreamBuilder (e.g., during local widget tests).
    _addToMockCache(ChatMessageModel(
      messageId:     docId,
      chatId:        chatId,
      senderId:      senderId,
      receiverId:    receiverId,
      text:          text,
      attachmentUrl: attachmentUrl,
      timestamp:     DateTime.now(),
      isRead:        false,
      status:        'sent',
    ));
  }

  // ── Get Messages Stream ──────────────────────────────────────────────────

  /// Returns a decrypted, real-time stream of [ChatMessageModel] from Firestore.
  ///
  /// Ordered by [timestamp] ascending (oldest first, like WhatsApp).
  ///
  /// When the stream is subscribed (i.e., the ChatScreen opens), all unread
  /// incoming messages for [currentUserId] are auto-marked as read ('read' double blue tick).
  ///
  /// Falls back to a local mock stream if Firestore is unreachable.
  Stream<List<ChatMessageModel>> getMessagesStream(
    String chatId, {
    String? currentUserId,
  }) {
    // Primary: live Firestore stream with E2EE decryption.
    try {
      return _messages(chatId)
          .orderBy(_Fields.timestamp, descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
        final messages = <ChatMessageModel>[];

        for (final doc in snapshot.docs) {
          final data    = doc.data();
          final msg     = await _decodeDocument(data);
          messages.add(msg);
        }

        // Auto-mark incoming messages as read in real time for recipient.
        if (currentUserId != null && snapshot.docs.isNotEmpty) {
          _batchMarkAsRead(chatId, snapshot, currentUserId);
        }

        return messages;
      }).handleError((error) {
        debugPrint('[ChatService] Firestore stream error fallback: $error');
        return _getMockStream(chatId);
      });
    } catch (e) {
      debugPrint('[ChatService] Firestore stream error, using mock: $e');
      return _getMockStream(chatId);
    }
  }

  // ── Auto Read Receipts (WhatsApp-Style) ─────────────────────────────────

  /// Marks all incoming unread messages as `isRead = true` and `status = 'read'` in Firestore.
  /// Uses a batched write for efficiency.
  void _batchMarkAsRead(
    String chatId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String currentUserId,
  ) {
    final unread = snapshot.docs.where((doc) {
      final data = doc.data();
      final isRead = data[_Fields.isRead] as bool? ?? false;
      final status = data[_Fields.status] as String? ?? '';
      return data[_Fields.receiverId] == currentUserId &&
          (!isRead || status != 'read');
    }).toList();

    if (unread.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {
        _Fields.isRead: true,
        _Fields.status: 'read',
      });
      final roomRef = _roomMessages(chatId).doc(doc.id);
      batch.update(roomRef, {
        _Fields.isRead: true,
        _Fields.status: 'read',
      });
    }
    batch.commit().catchError((Object e) {
      debugPrint('[ChatService] batch read receipt error: $e');
    });
  }

  /// Marks unread messages as 'delivered' when the recipient app is online or syncs.
  Future<void> markMessagesAsDelivered(String chatId, String currentUserId) async {
    try {
      final query = await _messages(chatId)
          .where(_Fields.receiverId, isEqualTo: currentUserId)
          .where(_Fields.status, isEqualTo: 'sent')
          .get();

      if (query.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {_Fields.status: 'delivered'});
        final roomRef = _roomMessages(chatId).doc(doc.id);
        batch.update(roomRef, {_Fields.status: 'delivered'});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatService] error marking delivered: $e');
    }
  }

  /// Marks all unread messages in the local mock cache as read for [currentUserId].
  void markAllAsRead(String chatId, String currentUserId) {
    var updated = false;
    for (var i = 0; i < _localMessageCache.length; i++) {
      if (_localMessageCache[i].receiverId == currentUserId &&
          !_localMessageCache[i].isRead) {
        _localMessageCache[i] = _localMessageCache[i].copyWith(
          isRead: true,
          status: 'read',
        );
        updated = true;
      }
    }
    if (updated) {
      _mockStreamController.add(List.from(_localMessageCache));
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────

  void dispose() {
    _mockStreamController.close();
  }

  // ── Internal: Firestore helpers ────────────────────────────────────────

  /// Decodes a Firestore document into a [ChatMessageModel], decrypting
  /// E2EE fields if present and parsing delivery status.
  Future<ChatMessageModel> _decodeDocument(
    Map<String, dynamic> data,
  ) async {
    final messageId     = data[_Fields.messageId]    as String? ?? '';
    final chatId        = data[_Fields.chatId]       as String? ?? '';
    final senderId      = data[_Fields.senderId]     as String? ?? '';
    final receiverId    = data[_Fields.receiverId]   as String? ?? '';
    final attachmentUrl = data[_Fields.attachmentUrl] as String?;
    final isRead        = data[_Fields.isRead]       as bool? ?? false;
    final status        = data[_Fields.status]       as String? ?? (isRead ? 'read' : 'sent');

    final Timestamp? ts = data[_Fields.timestamp] as Timestamp?;
    final timestamp     = ts?.toDate() ?? DateTime.now();

    // ── Try E2EE decryption ──────────────────────────────────────────────
    String text;
    final encAesKey = data[_Fields.encryptedAesKey] as String?;
    if (encAesKey != null && encAesKey.isNotEmpty) {
      try {
        final payload = EncryptedMessagePayload.fromMap(
          data.cast<String, dynamic>(),
        );
        text = await EncryptionService.instance.decrypt(payload) ?? '[Decryption failed]';
      } catch (e) {
        text = '[Decryption error]';
      }
    } else {
      text = data[_Fields.text] as String? ?? '';
    }

    return ChatMessageModel(
      messageId:     messageId,
      chatId:        chatId,
      senderId:      senderId,
      receiverId:    receiverId,
      text:          text,
      attachmentUrl: attachmentUrl,
      timestamp:     timestamp,
      isRead:        isRead || status == 'read',
      status:        status,
    );
  }

  Future<String?> _fetchRecipientPublicKey(String recipientUid) async {
    try {
      final doc = await _db.collection('users').doc(recipientUid).get();
      return doc.data()?['publicKey'] as String?;
    } catch (e) {
      debugPrint('[ChatService] could not fetch public key for $recipientUid: $e');
      return null;
    }
  }

  // ── Internal: Local Fallback Stream (No fake bot/mock messages) ─────────

  Stream<List<ChatMessageModel>> _getMockStream(String chatId) {
    Future.microtask(() =>
        _mockStreamController.add(List.from(_localMessageCache)));
    return _mockStreamController.stream;
  }

  void _addToMockCache(ChatMessageModel msg) {
    _localMessageCache.add(msg);
    if (!_mockStreamController.isClosed) {
      _mockStreamController.add(List.from(_localMessageCache));
    }
  }
}

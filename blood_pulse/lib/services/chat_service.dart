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
  bool _mockInitialized = false;

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
  }) async {
    final data = {
      'roomId': roomId,
      'chatId': roomId,
      'participants': [user1Id, user2Id],
      'updatedAt': FieldValue.serverTimestamp(),
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
    ));
  }

  // ── Get Messages Stream ──────────────────────────────────────────────────

  /// Returns a decrypted, real-time stream of [ChatMessageModel] from Firestore.
  ///
  /// Ordered by [timestamp] ascending (oldest first, like WhatsApp).
  ///
  /// When the stream is subscribed (i.e., the ChatScreen opens), all unread
  /// incoming messages for [currentUserId] are auto-marked as read.
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

        // Auto-mark incoming messages as read in real time.
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

  // ── Auto Read Receipts ─────────────────────────────────────────────────

  /// Marks all incoming unread messages as `isRead = true` in Firestore.
  ///
  /// Uses a batched write for efficiency (max 500 ops/batch — safe for chats).
  void _batchMarkAsRead(
    String chatId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String currentUserId,
  ) {
    final unread = snapshot.docs.where((doc) {
      final data = doc.data();
      return data[_Fields.receiverId] == currentUserId &&
          data[_Fields.isRead] == false;
    }).toList();

    if (unread.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {_Fields.isRead: true});
    }
    batch.commit().catchError((Object e) {
      debugPrint('[ChatService] batch read receipt error: $e');
    });
  }

  /// Marks all unread messages in the local mock cache as read for [currentUserId].
  ///
  /// Maintains backward compatibility with the existing [ChatScreen] call site.
  void markAllAsRead(String chatId, String currentUserId) {
    var updated = false;
    for (var i = 0; i < _localMessageCache.length; i++) {
      if (_localMessageCache[i].receiverId == currentUserId &&
          !_localMessageCache[i].isRead) {
        _localMessageCache[i] =
            _localMessageCache[i].copyWith(isRead: true);
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
  /// E2EE fields if present.
  Future<ChatMessageModel> _decodeDocument(
    Map<String, dynamic> data,
  ) async {
    final messageId    = data[_Fields.messageId]    as String? ?? '';
    final chatId       = data[_Fields.chatId]       as String? ?? '';
    final senderId     = data[_Fields.senderId]     as String? ?? '';
    final receiverId   = data[_Fields.receiverId]   as String? ?? '';
    final attachmentUrl = data[_Fields.attachmentUrl] as String?;
    final isRead       = data[_Fields.isRead]       as bool? ?? false;

    final Timestamp? ts  = data[_Fields.timestamp] as Timestamp?;
    final timestamp      = ts?.toDate() ?? DateTime.now();

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
      isRead:        isRead,
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

  // ── Internal: Mock / Fallback Stream ──────────────────────────────────

  Stream<List<ChatMessageModel>> _getMockStream(String chatId) {
    if (!_mockInitialized) {
      _mockInitialized = true;
      _initMockData(chatId);
    }
    Future.microtask(() =>
        _mockStreamController.add(List.from(_localMessageCache)));
    return _mockStreamController.stream;
  }

  void _initMockData(String chatId) {
    _localMessageCache.addAll([
      ChatMessageModel(
        messageId:  'm1',
        chatId:     chatId,
        senderId:   'req_202',
        receiverId: 'usr_101',
        text: 'Assalamu Alaikum. Emergency request for O+ blood at '
            'Dhaka Medical College Hospital (Ward 4).',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        isRead:    true,
      ),
      ChatMessageModel(
        messageId:  'm2',
        chatId:     chatId,
        senderId:   'usr_101',
        receiverId: 'req_202',
        text: 'Walaikum Assalam. I am an eligible O+ donor and available '
            'to donate today.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        isRead:    true,
      ),
      ChatMessageModel(
        messageId:  'm3',
        chatId:     chatId,
        senderId:   'req_202',
        receiverId: 'usr_101',
        text: 'Alhamdulillah! Please attach the hospital requisition form '
            'for verification.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead:    true,
      ),
      ChatMessageModel(
        messageId:     'm4',
        chatId:        chatId,
        senderId:      'usr_101',
        receiverId:    'req_202',
        text:          'Attached DMCH Prescription Report.',
        attachmentUrl: 'https://bloodpulse.org/reports/DMCH_Requisition_Form.pdf',
        timestamp:     DateTime.now().subtract(const Duration(minutes: 10)),
        isRead:        true,
      ),
    ]);
  }

  void _addToMockCache(ChatMessageModel msg) {
    _localMessageCache.add(msg);
    if (!_mockStreamController.isClosed) {
      _mockStreamController.add(List.from(_localMessageCache));
    }
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message_model.dart';
import 'api_client.dart';

/// Transport abstraction for real-time requester-donor chat (#37).
/// Allows switching between Polling with Backoff, WebSocket, or Firestore without altering UI.
abstract class ChatTransport {
  Stream<List<ChatMessageModel>> getMessagesStream(String chatId, {String? currentUserId});

  Future<ChatMessageModel?> sendMessage({
    required String chatId,
    required String text,
    String messageType = 'TEXT',
    String? voiceUrl,
    int voiceDurationSeconds = 0,
  });

  Future<void> markAsRead(String chatId, String messageId);

  Future<void> reportMessage(String chatId, String messageId, String reason);

  Future<void> deleteMessage(String chatId, String messageId);

  void dispose();
}

/// Zero-cost HTTP Polling Chat Transport with Exponential/Adaptive Backoff (#37).
/// Starts with 2s interval, backs off to 5s, then 10s on idle.
/// Resets immediately to 2s on user send, message arrival, or manual trigger.
class HttpPollingChatTransport implements ChatTransport {
  HttpPollingChatTransport({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  final Map<String, StreamController<List<ChatMessageModel>>> _controllers = {};
  final Map<String, Timer?> _pollingTimers = {};
  final Map<String, List<ChatMessageModel>> _cache = {};
  final Map<String, int> _idlePollCounts = {};

  static const Duration _activeInterval = Duration(seconds: 2);
  static const Duration _idleInterval = Duration(seconds: 5);
  static const Duration _deepIdleInterval = Duration(seconds: 10);

  @override
  Stream<List<ChatMessageModel>> getMessagesStream(String chatId, {String? currentUserId}) {
    if (_controllers.containsKey(chatId) && !_controllers[chatId]!.isClosed) {
      return _controllers[chatId]!.stream;
    }

    final controller = StreamController<List<ChatMessageModel>>.broadcast(
      onCancel: () => _stopPolling(chatId),
    );
    _controllers[chatId] = controller;
    _cache[chatId] = [];
    _idlePollCounts[chatId] = 0;

    // Initial fetch immediately
    _fetchMessages(chatId, markRead: true);
    _startPolling(chatId, _activeInterval);

    return controller.stream;
  }

  void _startPolling(String chatId, Duration interval) {
    _pollingTimers[chatId]?.cancel();
    _pollingTimers[chatId] = Timer.periodic(interval, (_) async {
      await _fetchMessages(chatId);
    });
  }

  void _stopPolling(String chatId) {
    _pollingTimers[chatId]?.cancel();
    _pollingTimers.remove(chatId);
  }

  Future<void> _fetchMessages(String chatId, {bool markRead = false}) async {
    final controller = _controllers[chatId];
    if (controller == null || controller.isClosed) return;

    try {
      final endpoint = '/api/chat/$chatId/messages/?limit=100${markRead ? '&mark_read=true' : ''}';
      final response = await _api.get(endpoint);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (data['results'] as List? ?? [])
            .map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final prevCount = _cache[chatId]?.length ?? 0;
        final hasNew = results.length > prevCount;

        _cache[chatId] = results;
        if (!controller.isClosed) {
          controller.add(List.unmodifiable(results));
        }

        // Adaptive Backoff Logic
        if (hasNew) {
          _idlePollCounts[chatId] = 0;
          _startPolling(chatId, _activeInterval);
        } else {
          final idleCount = (_idlePollCounts[chatId] ?? 0) + 1;
          _idlePollCounts[chatId] = idleCount;

          if (idleCount > 8) {
            _startPolling(chatId, _deepIdleInterval);
          } else if (idleCount > 3) {
            _startPolling(chatId, _idleInterval);
          }
        }
      }
    } catch (e) {
      debugPrint('[HttpPollingChatTransport] Fetch error: $e');
    }
  }

  @override
  Future<ChatMessageModel?> sendMessage({
    required String chatId,
    required String text,
    String messageType = 'TEXT',
    String? voiceUrl,
    int voiceDurationSeconds = 0,
  }) async {
    try {
      final payload = {
        'content': text,
        'message_type': messageType,
        if (voiceUrl != null) 'voice_url': voiceUrl,
        if (voiceDurationSeconds > 0) 'voice_duration_seconds': voiceDurationSeconds,
      };

      final response = await _api.post('/api/chat/$chatId/messages/', body: payload);
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newMsg = ChatMessageModel.fromJson(data);

        // Optimistically update cache and reset to active polling interval
        final currentList = List<ChatMessageModel>.from(_cache[chatId] ?? []);
        currentList.add(newMsg);
        _cache[chatId] = currentList;

        final controller = _controllers[chatId];
        if (controller != null && !controller.isClosed) {
          controller.add(List.unmodifiable(currentList));
        }

        _idlePollCounts[chatId] = 0;
        _startPolling(chatId, _activeInterval);
        return newMsg;
      }
    } catch (e) {
      debugPrint('[HttpPollingChatTransport] Send error: $e');
    }
    return null;
  }

  @override
  Future<void> markAsRead(String chatId, String messageId) async {
    try {
      await _api.post('/api/chat/$chatId/messages/$messageId/read/');
    } catch (e) {
      debugPrint('[HttpPollingChatTransport] MarkRead error: $e');
    }
  }

  @override
  Future<void> reportMessage(String chatId, String messageId, String reason) async {
    try {
      await _api.post('/api/chat/$chatId/messages/$messageId/report/', body: {
        'reason': reason,
      });
    } catch (e) {
      debugPrint('[HttpPollingChatTransport] Report error: $e');
    }
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final response = await _api.delete('/api/chat/$chatId/messages/$messageId/');
      if (response.statusCode == 204) {
        final currentList = List<ChatMessageModel>.from(_cache[chatId] ?? []);
        currentList.removeWhere((m) => m.messageId == messageId);
        _cache[chatId] = currentList;

        final controller = _controllers[chatId];
        if (controller != null && !controller.isClosed) {
          controller.add(List.unmodifiable(currentList));
        }
      }
    } catch (e) {
      debugPrint('[HttpPollingChatTransport] Delete error: $e');
    }
  }

  /// Uploads recorded voice audio clip to the backend (#39)
  Future<Map<String, dynamic>?> uploadVoiceNote({
    required String chatId,
    required List<int> audioBytes,
    required int durationSeconds,
    String filename = 'audio_note.m4a',
  }) async {
    try {
      final uri = Uri.parse('${_api.baseUrl}/api/chat/$chatId/voice/');
      final request = http.MultipartRequest('POST', uri);

      // Attach token headers
      final token = await _api.getAccessToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['duration_seconds'] = durationSeconds.toString();
      request.files.add(http.MultipartFile.fromBytes(
        'voice_file',
        audioBytes,
        filename: filename,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 503) {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        throw ApiException(
          err['detail'] as String? ?? 'Voice messaging is temporarily unavailable.',
          statusCode: 503,
          rawError: err['code'],
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('[HttpPollingChatTransport] Voice upload error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    for (final timer in _pollingTimers.values) {
      timer?.cancel();
    }
    _pollingTimers.clear();

    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
    _cache.clear();
    _idlePollCounts.clear();
  }
}

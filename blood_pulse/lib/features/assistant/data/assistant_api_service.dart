// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../../services/api_client.dart'; // Standard API client using token
import '../domain/models/assistant_message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assistantApiProvider = Provider((ref) => AssistantApiService(ApiClient()));

class AssistantApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  AssistantApiException(this.code, this.message, {this.statusCode});

  @override
  String toString() => 'AssistantApiException($code: $message, statusCode: $statusCode)';
}

class AssistantApiService {
  final ApiClient _client;

  AssistantApiService(this._client);

  Future<AssistantMessage> sendMessage(
    String message,
    String locale, {
    int? conversationId,
    String? screenContext,
    int attempt = 0,
  }) async {
    try {
      final response = await _client.post(
        '/api/assistant/chat/',
        body: {
          'message': message,
          'locale': locale,
          if (conversationId != null) 'conversation_id': conversationId,
          if (screenContext != null) 'screen_context': screenContext,
        },
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().isEmpty) {
          throw AssistantApiException('EMPTY_RESPONSE', 'Empty response from server', statusCode: response.statusCode);
        }
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          final replyText = json['reply'] ?? json['response'] ?? '';
          if (replyText.toString().trim().isEmpty) {
            throw AssistantApiException('EMPTY_RESPONSE', 'Empty reply from assistant', statusCode: response.statusCode);
          }
        }
        return AssistantMessage.fromJson(json);
      }

      final code = _mapStatusCode(response.statusCode, response.body);
      throw AssistantApiException(code, response.body, statusCode: response.statusCode);
    } on ApiException catch (e) {
      final code = _mapStatusCode(e.statusCode, e.message);
      throw AssistantApiException(code, e.message, statusCode: e.statusCode);
    } on SocketException catch (e) {
      throw AssistantApiException('NO_INTERNET', e.message, statusCode: 0);
    } on TimeoutException catch (e) {
      throw AssistantApiException('TIMEOUT', e.message ?? 'timeout', statusCode: 408);
    } on FormatException catch (e) {
      throw AssistantApiException('EMPTY_RESPONSE', e.message, statusCode: 500);
    }
  }

  String _mapStatusCode(int? status, String? body) {
    if (status == 401) return 'LOGIN_REQUIRED';
    if (status == 429) return 'RATE_LIMITED';
    if (status == 408 || status == 504) return 'TIMEOUT';
    if (status == 503 || status == 502) {
      if (body != null && (body.toLowerCase().contains('provider') || body.toLowerCase().contains('gemini'))) {
        return 'PROVIDER_ERROR';
      }
      return 'SERVER_ERROR';
    }
    if (status != null && status >= 500) return 'SERVER_ERROR';
    if (body != null && body.toLowerCase().contains('provider')) return 'PROVIDER_ERROR';
    if (body != null && body.toLowerCase().contains('timeout')) return 'TIMEOUT';
    return 'GENERIC_ERROR';
  }

  Future<List<QuickAction>> getQuickActions() async {
    final response = await _client.get('/api/assistant/quick-actions/');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => QuickAction.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> sendFeedback(int messageId, String rating, {String? reason, String? note}) async {
    await _client.post('/api/assistant/feedback/', body: {
      'message_id': messageId,
      'rating': rating,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
    });
  }

  Future<void> handoffSupport({required String subject, required String message, required String contactPreference}) async {
    final response = await _client.post('/api/assistant/handoff/', body: {
      'subject': subject,
      'message': message,
      'contact_preference': contactPreference,
    });
    if (response.statusCode >= 400) throw Exception('Handoff failed');
  }

  Future<void> saveConsent(bool consent) async {
    await _client.post('/api/assistant/consent/', body: {
      'logging_consent': consent,
    });
  }

  Future<void> clearConversations() async {
    await _client.delete('/api/assistant/conversations/');
  }
}

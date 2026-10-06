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
        final json = jsonDecode(response.body);
        return AssistantMessage.fromJson(json);
      }

      if (response.statusCode == 429 && attempt < 3) {
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
        return await sendMessage(
          message,
          locale,
          conversationId: conversationId,
          screenContext: screenContext,
          attempt: attempt + 1,
        );
      }

      String code;
      if (response.statusCode == 401) {
        code = 'LOGIN_REQUIRED';
      } else if (response.statusCode == 404) {
        code = 'NOT_AVAILABLE';
      } else if (response.statusCode == 429) {
        code = 'RATE_LIMITED';
      } else if (response.statusCode == 413) {
        code = 'MESSAGE_TOO_LONG';
      } else if (response.statusCode == 402) {
        code = 'BUDGET_REACHED';
      } else if (response.statusCode >= 500) {
        code = 'SERVER_ERROR';
      } else {
        code = 'GENERIC_ERROR';
      }
      throw AssistantApiException(code, response.body, statusCode: response.statusCode);
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    }
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

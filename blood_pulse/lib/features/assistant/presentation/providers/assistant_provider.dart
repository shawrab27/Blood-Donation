// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../domain/models/assistant_message_model.dart';
import '../../data/assistant_api_service.dart';

final assistantProvider = StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
  return AssistantNotifier(ref.read(assistantApiProvider));
});

class AssistantState {
  final List<AssistantMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorCode;
  final String? requestId;
  final String? lastFailedText;
  final List<QuickAction> quickActions;
  final bool consentGiven;
  final bool isFirstRun;
  final int? conversationId;

  AssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorCode,
    this.requestId,
    this.lastFailedText,
    this.quickActions = const [],
    this.consentGiven = false,
    this.isFirstRun = true,
    this.conversationId,
  });

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorCode,
    String? requestId,
    String? lastFailedText,
    List<QuickAction>? quickActions,
    bool? consentGiven,
    bool? isFirstRun,
    int? conversationId,
    bool clearError = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      requestId: clearError ? null : (requestId ?? this.requestId),
      lastFailedText: clearError ? null : (lastFailedText ?? this.lastFailedText),
      quickActions: quickActions ?? this.quickActions,
      consentGiven: consentGiven ?? this.consentGiven,
      isFirstRun: isFirstRun ?? this.isFirstRun,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantApiService _apiService;
  Box? _box;

  AssistantNotifier(this._apiService) : super(AssistantState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final box = await Hive.openBox('assistant_box');
      if (!mounted) return;
      _box = box;
      
      // Load local history
      final history = _box?.get('history', defaultValue: <String>[]);
      final List<AssistantMessage> msgs = (history is List ? history : []).map((e) {
        return AssistantMessage.fromJson(jsonDecode(e as String));
      }).toList();
      
      final bool firstRun = _box?.get('first_run', defaultValue: true) ?? true;
      final bool consent = _box?.get('consent', defaultValue: false) ?? false;
      final int? convId = _box?.get('conversation_id');

      if (!mounted) return;
      state = state.copyWith(
        messages: msgs,
        isFirstRun: firstRun,
        consentGiven: consent,
        conversationId: convId,
      );

      _loadQuickActions();
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> _loadQuickActions() async {
    try {
      final actions = await _apiService.getQuickActions();
      if (!mounted) return;
      state = state.copyWith(quickActions: actions, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  void _saveToLocal() {
    if (_box == null || !_box!.isOpen) return;
    // keep last 30
    final msgs = state.messages.length > 30 
      ? state.messages.sublist(state.messages.length - 30)
      : state.messages;
      
    final historyList = msgs.map((m) => jsonEncode(m.toJson())).toList();
    _box!.put('history', historyList);
    if (state.conversationId != null) {
      _box!.put('conversation_id', state.conversationId);
    }
  }

  Future<void> saveConsent(bool consent) async {
    if (_box != null && _box!.isOpen) {
      await _box!.put('first_run', false);
      await _box!.put('consent', consent);
    }
    if (!mounted) return;
    state = state.copyWith(isFirstRun: false, consentGiven: consent);
    try {
      await _apiService.saveConsent(consent);
    } catch (_) {}
  }

  Future<void> sendMessage(String text, String locale, {String? screenContext, bool isRetry = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final isSameAsLastUser = state.messages.isNotEmpty &&
        state.messages.last.isUser &&
        state.messages.last.text.trim() == trimmed;

    final shouldAppendUserBubble = !isRetry && !isSameAsLastUser;

    final updatedMessages = shouldAppendUserBubble
        ? [...state.messages, AssistantMessage(isUser: true, text: trimmed)]
        : state.messages;

    state = state.copyWith(
      messages: updatedMessages,
      isSending: true,
      clearError: true,
    );
    if (shouldAppendUserBubble) {
      _saveToLocal();
    }

    try {
      final reply = await _apiService.sendMessage(
        trimmed, 
        locale, 
        conversationId: state.conversationId,
        screenContext: screenContext,
      );

      state = state.copyWith(
        messages: [...state.messages, reply],
        isSending: false,
        conversationId: reply.conversationId ?? state.conversationId,
        requestId: reply.requestId,
        clearError: true,
      );
      _saveToLocal();
    } on AssistantApiException catch (e) {
      state = state.copyWith(
        isSending: false,
        errorCode: e.code,
        requestId: e.requestId,
        lastFailedText: trimmed,
      );
    } on SocketException {
      state = state.copyWith(
        isSending: false,
        errorCode: 'NO_INTERNET',
        lastFailedText: trimmed,
      );
    } on TimeoutException {
      state = state.copyWith(
        isSending: false,
        errorCode: 'TIMEOUT',
        lastFailedText: trimmed,
      );
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        errorCode: 'GENERIC_ERROR',
        lastFailedText: trimmed,
      );
    }
  }

  Future<void> retryLastMessage(String locale, {String? screenContext}) async {
    final textToRetry = state.lastFailedText ??
        (state.messages.reversed
            .firstWhere(
              (m) => m.isUser,
              orElse: () => AssistantMessage(isUser: true, text: ''),
            )
            .text);
    if (textToRetry.trim().isEmpty) return;
    await sendMessage(textToRetry, locale, screenContext: screenContext, isRetry: true);
  }

  Future<void> sendFeedback(AssistantMessage message, String rating, {String? reason, String? note}) async {
    if (message.id == null) return;
    
    // Optimistic UI update for thumbs down to show form
    if (rating == 'DOWN') {
      final index = state.messages.indexOf(message);
      if (index != -1) {
        final updatedMsgs = List<AssistantMessage>.from(state.messages);
        updatedMsgs[index] = message.copyWith(hasThumbsDown: true);
        state = state.copyWith(messages: updatedMsgs);
        _saveToLocal();
      }
    }

    try {
      await _apiService.sendFeedback(message.id!, rating, reason: reason, note: note);
    } catch (_) {}
  }
  
  Future<void> submitHandoff(String subject, String message, String preference) async {
    await _apiService.handoffSupport(subject: subject, message: message, contactPreference: preference);
  }

  Future<void> clearChat() async {
    state = state.copyWith(messages: [], conversationId: null);
    await _box?.delete('history');
    await _box?.delete('conversation_id');
    try {
      await _apiService.clearConversations();
    } catch (_) {}
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_client.dart';

class NotificationCountNotifier extends StateNotifier<int> {
  final ApiClient _apiClient;
  Timer? _pollingTimer;

  NotificationCountNotifier({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        super(0) {
    fetchUnreadCount();
    // Poll every 30 seconds for real-time unread badge updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchUnreadCount();
    });
  }

  Future<void> fetchUnreadCount() async {
    try {
      final token = await _apiClient.getAccessToken();
      if (token == null) {
        state = 0;
        return;
      }
      final response = await _apiClient.get('notifications/unread-count/');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final count = (data['unread_count'] as num?)?.toInt() ?? 0;
        state = count;
      }
    } catch (e) {
      debugPrint('[NotificationCountNotifier] Error fetching unread count: $e');
    }
  }

  Future<void> markAsRead() async {
    state = 0;
    try {
      await _apiClient.post('notifications/mark-read/');
    } catch (e) {
      debugPrint('[NotificationCountNotifier] Error marking notifications as read: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final notificationCountProvider =
    StateNotifierProvider<NotificationCountNotifier, int>((ref) {
  return NotificationCountNotifier();
});

/// BloodPulse — FCM Push Notification Service
///
/// Production-grade Firebase Cloud Messaging singleton that:
///  1. Requests foreground/background notification permissions on all platforms.
///  2. Initializes FlutterLocalNotificationsPlugin for in-app foreground notification alerts
///     on the 'bloodpulse_urgent_alerts' channel.
///  3. Subscribes users to regional blood-group topics for emergency dispatch.
///  4. Routes high-urgency FCM payloads to [NotificationWallpaperOverlay] or Blood Hub details.
///  5. Handles "Call Now" → `tel:` via [url_launcher] and
///     "Message / Chat" → GoRouter `/chat` navigation.
///
/// FCM topic naming convention:
///   `bp_<district>_<bloodGroup>`  e.g., `bp_dhaka_o_positive`
library;

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/notifications/presentation/screens/notification_wallpaper_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background message handler — MUST be a top-level function.
// ─────────────────────────────────────────────────────────────────────────────

/// Handles messages received when the app is in the background or terminated.
///
/// Runs in a separate isolate on Android; do not call any Flutter UI code here.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('[FCM-BG] title=${message.notification?.title} type=${message.data['type']}');
  try {
    await Hive.initFlutter();
    final box = Hive.isBoxOpen('notifications_box')
        ? Hive.box('notifications_box')
        : await Hive.openBox('notifications_box');
    final title = message.notification?.title ?? message.data['title'] as String? ?? 'BloodPulse Alert';
    final body = message.notification?.body ?? message.data['body'] as String? ?? '';
    final type = message.data['type'] as String? ?? 'general';
    await box.add({
      'title': title,
      'body': body,
      'type': type,
      'data': Map<String, dynamic>.from(message.data),
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
    });
  } catch (e) {
    debugPrint('[FCM-BG] Hive cache error: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FcmService
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton FCM service.
///
/// Call [FcmService.instance.initialize] once from [main] or the root widget's
/// [initState] after [FirebaseApp] has been initialised.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _isInitialized = false;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _emergencyChannel = AndroidNotificationChannel(
    'bloodpulse_urgent_alerts',
    'Urgent Alerts',
    description: 'Critical blood donation alerts and chat updates',
    importance: Importance.max,
    playSound: true,
  );

  // ── Initialise ─────────────────────────────────────────────────────────

  /// Bootstraps FCM, requests permissions, wires foreground & tap handlers,
  /// initializes local notifications, and subscribes to the user's blood-group topic.
  ///
  /// [context]         — Must be mounted. Used to show [NotificationWallpaperOverlay].
  /// [userUid]         — Logged-in user UID (for token association).
  /// [district]        — User's district slug, e.g. `"dhaka"`.
  /// [bloodGroupSlug]  — Normalised blood-group slug, e.g. `"o_positive"`.
  ///                     Pass `null` to skip topic subscription.
  Future<void> initialize({
    required BuildContext context,
    required String userUid,
    String district = 'dhaka',
    String? bloodGroupSlug,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Register background handler first
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // ── Local Notifications Plugin Init (for Foreground Banners) ──
    await _initLocalNotifications(context);

    // ── Permission Request ──────────────────────────────────────────────
    await _requestPermissions();

    // ── Token Retrieval ─────────────────────────────────────────────────
    await _logToken(userUid);

    // ── Topic Subscription ──────────────────────────────────────────────
    await subscribeToRegion(district: district);
    if (bloodGroupSlug != null) {
      await subscribeToBloodGroup(
        district: district,
        bloodGroupSlug: bloodGroupSlug,
      );
    }

    // ── Foreground Message Handler ──────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (context.mounted) {
        _handleForegroundMessage(msg, context);
      }
    });

    // ── Notification-Tap Handler (background → opened) ──────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      if (context.mounted) {
        _handleNotificationTap(msg, context);
      }
    });

    // ── Check if app was launched from a terminated-state notification ──
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && context.mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        _handleNotificationTap(initialMessage, context);
      }
    }
  }

  // ── Local Notifications Setup ──────────────────────────────────────────

  Future<void> _initLocalNotifications(BuildContext context) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && context.mounted) {
            try {
              final payload = jsonDecode(response.payload!) as Map<String, dynamic>;
              handleBackgroundNotificationPayload(payload, context);
            } catch (_) {}
          }
        },
      );

      // Create Android Notification Channel
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_emergencyChannel);
    } catch (e) {
      debugPrint('[FCM] Local notifications init notice: $e');
    }
  }

  // ── Permission Helpers ─────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    try {
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true, // iOS: critical alerts bypass Do Not Disturb
        provisional: false,
        announcement: false,
        carPlay: false,
      );

      debugPrint('[FCM] permission: ${settings.authorizationStatus.name}');

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[FCM] permission request error: $e');
    }
  }

  // ── Token Retrieval ────────────────────────────────────────────────────

  Future<void> _logToken(String userUid) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] device token for $userUid: $token');
    } catch (e) {
      debugPrint('[FCM] token fetch error: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] token refreshed: $newToken');
    });
  }

  // ── Topic Subscription ─────────────────────────────────────────────────

  /// Subscribes this device to the emergency dispatch topic for [district].
  /// Topic format: `bp_<district>` (e.g., `bp_dhaka`)
  Future<void> subscribeToRegion({required String district}) async {
    try {
      final topic = 'bp_${_slugify(district)}';
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('[FCM] subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] subscribeToRegion error: $e');
    }
  }

  /// Subscribes to a specific blood-group topic within a district.
  /// Topic format: `bp_<district>_<bloodGroupSlug>`
  /// e.g., `bp_dhaka_ab_positive`, `bp_chittagong_o_negative`
  Future<void> subscribeToBloodGroup({
    required String district,
    required String bloodGroupSlug,
  }) async {
    try {
      final topic = 'bp_${_slugify(district)}_${_slugify(bloodGroupSlug)}';
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('[FCM] subscribed to blood-group topic: $topic');
    } catch (e) {
      debugPrint('[FCM] subscribeToBloodGroup error: $e');
    }
  }

  /// Unsubscribes from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('[FCM] unsubscribed from: $topic');
    } catch (e) {
      debugPrint('[FCM] unsubscribeFromTopic error: $e');
    }
  }

  // ── Message Handlers ───────────────────────────────────────────────────

  /// Called when a message arrives while the app is in the foreground.
  void _handleForegroundMessage(
    RemoteMessage message,
    BuildContext context,
  ) {
    final data = message.data;
    final notification = message.notification;
    final type = data['type'] as String? ?? '';
    final isEmergency = type == 'EMERGENCY_REQUEST';

    final title = notification?.title ?? data['title'] as String? ?? 'BloodPulse Alert';
    final body = notification?.body ?? data['body'] as String? ?? 'New emergency blood update available.';

    debugPrint('[FCM] foreground: title=$title, type=$type, isEmergency=$isEmergency');

    // Persist to Hive notifications_box for offline viewing
    saveNotificationToCache(
      title: title,
      body: body,
      type: type,
      data: data,
    );

    // 1. Show Foreground Local Heads-Up Notification Banner
    _showForegroundLocalNotification(
      title: title,
      body: body,
      payload: data,
    );

    // 2. If high urgency emergency, also display the emergency overlay
    if (isEmergency && context.mounted) {
      _showEmergencyOverlay(data, context);
    }
  }

  /// Persists a notification to the local Hive [notifications_box].
  Future<void> saveNotificationToCache({
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
    bool isRead = false,
  }) async {
    try {
      final box = Hive.isBoxOpen('notifications_box')
          ? Hive.box('notifications_box')
          : await Hive.openBox('notifications_box');
      await box.add({
        'title': title,
        'body': body,
        'type': type,
        'data': data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{},
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': isRead,
      });
    } catch (e) {
      debugPrint('[FCM-Hive] Error saving notification: $e');
    }
  }

  Future<void> _showForegroundLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'bloodpulse_urgent_alerts',
        'Urgent Alerts',
        channelDescription: 'Critical blood donation alerts and chat updates',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[FCM] Failed to show foreground local notification: $e');
    }
  }

  /// Called when the user taps a notification to open the app.
  void _handleNotificationTap(
    RemoteMessage message,
    BuildContext context,
  ) {
    final data = message.data;
    final type = data['type'] as String? ?? '';
    final chatId = data['chatId'] as String?;

    debugPrint('[FCM] tapped: type=$type chatId=$chatId');

    if (type == 'EMERGENCY_REQUEST' && context.mounted) {
      context.go('/blood-hub');
    } else if ((type == 'CHAT_MESSAGE' || chatId != null) && context.mounted) {
      _navigateToChat(chatId ?? 'chat_999', context);
    }
  }

  /// Handles background/terminated payloads that are surfaced via a UI bridge.
  void handleBackgroundNotificationPayload(
    Map<String, dynamic> payload,
    BuildContext context,
  ) {
    final type = payload['type'] as String? ?? '';
    if (type == 'EMERGENCY_REQUEST' && context.mounted) {
      context.go('/blood-hub');
    } else if (type == 'CHAT_MESSAGE' && context.mounted) {
      _navigateToChat(
        payload['chatId'] as String? ?? 'chat_999',
        context,
      );
    }
  }

  // ── Quick Action: Call Now ─────────────────────────────────────────────

  Future<void> callRequester(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('[FCM] cannot launch tel: $phoneNumber');
    }
  }

  // ── Quick Action: Message / Chat ───────────────────────────────────────

  void _navigateToChat(String chatId, BuildContext context) {
    if (!context.mounted) return;
    context.push('/chat', extra: chatId);
  }

  // ── Internal helpers ───────────────────────────────────────────────────

  void _showEmergencyOverlay(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    NotificationWallpaperOverlay.showFromPayload(context, data);
  }

  String _slugify(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

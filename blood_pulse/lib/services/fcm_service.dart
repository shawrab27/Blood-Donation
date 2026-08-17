/// BloodPulse — FCM Push Notification Service
///
/// Production-grade Firebase Cloud Messaging singleton that:
///  1. Requests foreground/background notification permissions on all platforms.
///  2. Subscribes users to regional blood-group topics for emergency dispatch.
///  3. Routes high-urgency FCM payloads to [NotificationWallpaperOverlay].
///  4. Handles "Call Now" → `tel:` via [url_launcher] and
///     "Message / Chat" → GoRouter `/chat` navigation.
///
/// FCM topic naming convention:
///   `bp_<district>_<bloodGroup>`  e.g., `bp_dhaka_o_positive`
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  // In a real app you might update a local notification badge count or
  // trigger a local notification library here. No UI access is available.
  debugPrint('[FCM-BG] title=${message.notification?.title} '
      'type=${message.data['type']}');
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

  // ── Initialise ─────────────────────────────────────────────────────────

  /// Bootstraps FCM, requests permissions, wires foreground & tap handlers,
  /// and subscribes to the user's blood-group topic.
  ///
  /// [context]         — Must be mounted. Used to show [NotificationWallpaperOverlay].
  /// [userUid]         — Logged-in user UID (for token association).
  /// [district]        — User's district slug, e.g. `"dhaka"`.
  /// [bloodGroupSlug]  — Normalised blood-group slug, e.g. `"o_positive"`.
  ///                     Pass `null` to skip topic subscription.
  Future<void> initialize({
    required BuildContext context,
    required String userUid,
    String district       = 'dhaka',
    String? bloodGroupSlug,
  }) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Register the background handler first (platform requirement).
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

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
      // Small delay so the widget tree is fully built.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        _handleNotificationTap(initialMessage, context);
      }
    }
  }

  // ── Permission Helpers ─────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    final NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      criticalAlert: true,  // iOS: critical alerts bypass Do Not Disturb
      provisional:   false,
      announcement:  false,
      carPlay:       false,
    );

    // On Android API < 33, permission is always granted implicitly.
    // On Web, requestPermission shows the browser prompt.
    debugPrint('[FCM] permission: ${settings.authorizationStatus.name}');

    // Foreground notification display on iOS (default is .none).
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Token Retrieval ────────────────────────────────────────────────────

  Future<void> _logToken(String userUid) async {
    try {
      // APNS token must be fetched first on iOS.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] device token for $userUid: $token');
      // In production: write token to Firestore /users/{uid}/fcmToken
    } catch (e) {
      debugPrint('[FCM] token fetch error: $e');
    }

    // Listen for token refresh (happens after iOS backup restore, etc.)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] token refreshed: $newToken');
      // In production: update Firestore /users/{uid}/fcmToken
    });
  }

  // ── Topic Subscription ─────────────────────────────────────────────────

  /// Subscribes this device to the emergency dispatch topic for [district].
  ///
  /// Topic format: `bp_<district>`  (e.g., `bp_dhaka`)
  Future<void> subscribeToRegion({required String district}) async {
    final topic = 'bp_${_slugify(district)}';
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    debugPrint('[FCM] subscribed to topic: $topic');
  }

  /// Subscribes to a specific blood-group topic within a district.
  ///
  /// Topic format: `bp_<district>_<bloodGroupSlug>`
  /// e.g., `bp_dhaka_ab_positive`, `bp_chittagong_o_negative`
  Future<void> subscribeToBloodGroup({
    required String district,
    required String bloodGroupSlug,
  }) async {
    final topic = 'bp_${_slugify(district)}_${_slugify(bloodGroupSlug)}';
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    debugPrint('[FCM] subscribed to blood-group topic: $topic');
  }

  /// Unsubscribes from a topic (e.g., when user changes district or blood group).
  Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    debugPrint('[FCM] unsubscribed from: $topic');
  }

  // ── Message Handlers ───────────────────────────────────────────────────

  /// Called when a message arrives while the app is in the foreground.
  void _handleForegroundMessage(
    RemoteMessage message,
    BuildContext context,
  ) {
    final data   = message.data;
    final type   = data['type'] as String? ?? '';
    final isHigh = type == 'EMERGENCY_REQUEST';

    debugPrint('[FCM] foreground: type=$type, isEmergency=$isHigh');

    if (isHigh && context.mounted) {
      _showEmergencyOverlay(data, context);
    }
  }

  /// Called when the user taps a notification to open the app.
  void _handleNotificationTap(
    RemoteMessage message,
    BuildContext context,
  ) {
    final data   = message.data;
    final type   = data['type'] as String? ?? '';
    final chatId = data['chatId'] as String?;

    debugPrint('[FCM] tapped: type=$type chatId=$chatId');

    if (type == 'EMERGENCY_REQUEST' && context.mounted) {
      _showEmergencyOverlay(data, context);
    } else if ((type == 'CHAT_MESSAGE' || chatId != null) && context.mounted) {
      _navigateToChat(chatId ?? 'chat_999', context);
    }
  }

  /// Handles background/terminated payloads that are surfaced via a UI bridge.
  ///
  /// Call this from any widget when a payload is received outside the
  /// Firebase listener (e.g., from a local notification library callback).
  void handleBackgroundNotificationPayload(
    Map<String, dynamic> payload,
    BuildContext context,
  ) {
    final type = payload['type'] as String? ?? '';
    if (type == 'EMERGENCY_REQUEST' && context.mounted) {
      _showEmergencyOverlay(payload, context);
    } else if (type == 'CHAT_MESSAGE' && context.mounted) {
      _navigateToChat(
        payload['chatId'] as String? ?? 'chat_999',
        context,
      );
    }
  }

  // ── Quick Action: Call Now ─────────────────────────────────────────────

  /// Launches a `tel:` intent for the given [phoneNumber].
  ///
  /// Integrates with [NotificationWallpaperOverlay]'s "Call Now" button.
  Future<void> callRequester(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('[FCM] cannot launch tel: $phoneNumber');
    }
  }

  // ── Quick Action: Message / Chat ───────────────────────────────────────

  /// Navigates to the [ChatScreen] pre-filled with [chatId].
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

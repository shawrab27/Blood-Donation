// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/ecg_loader.dart';
import '../../../../core/widgets/pressable_scale.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/chat_message_model.dart';
import '../../../../services/api_client.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/fcm_service.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../blood_hub/data/blood_hub_api_service.dart';
import '../../domain/providers/notification_provider.dart';

/// Notification Center Screen implementing the Notification Exception Rule & Stitch Card UI.
///
/// Shows 4 notification filter categories:
///   1. Feed (Likes, comments, posts)
///   2. Request (Emergency blood request alerts)
///   3. Messages (P2P donor chats)
///   4. Profile (Cooldown countdown & badges)
class NotificationCenterScreen extends ConsumerStatefulWidget {
  final ApiClient? apiClient;
  const NotificationCenterScreen({super.key, this.apiClient});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  int _selectedFilterIndex = 0;
  String? _isAcceptingRequestId; // 0: Feed, 1: Request, 2: Messages, 3: Profile
  Timer? _pollingTimer;
  AppLifecycleListener? _lifecycleListener;
  List<Map<String, dynamic>> _serverNotifications = [];
  late final ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ref.read(apiClientProvider);
    _fetchServerNotifications();

    // Poll every 10s while app is open for real-time live updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchServerNotifications();
    });

    try {
      _lifecycleListener = AppLifecycleListener(
        onResume: () {
          if (mounted) {
            _fetchServerNotifications();
            ref.read(notificationCountProvider.notifier).fetchUnreadCount();
          }
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }


  Future<void> _handleRespond(String? requestId, Map<String, dynamic> rawData) async {
    if (requestId == null || requestId.isEmpty) {
      context.go('/blood-hub');
      return;
    }

    final reqIdInt = int.tryParse(requestId);
    if (reqIdInt == null) {
      context.go('/blood-hub');
      return;
    }

    setState(() => _isAcceptingRequestId = requestId);

    try {
      final api = ref.read(bloodHubApiServiceProvider);
      final res = await api.acceptBloodRequest(
        reqIdInt,
        supportStatus: 'CAN_SUPPORT',
        unitsPledged: 1,
      );

      if (!mounted) return;

      final acceptanceData = res['acceptance'] as Map<String, dynamic>?;
      int? journeyId = (res['acceptance_id'] as num?)?.toInt() ??
          (acceptanceData?['id'] as num?)?.toInt();
      if (journeyId == null || journeyId <= 0) {
        journeyId = await api.resolveJourneyIdFromRequestId(reqIdInt);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Requisition Accepted! Real contact & live tracking unlocked.',
            style: TextStyle(fontFamily: 'Inter', color: Colors.white),
          ),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      ref.invalidate(journeyDetailProvider(journeyId));
      context.push('/journeys/$journeyId');
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();

      // If already responded/accepted, route directly to the active journey!
      if (errStr.contains('already responded') ||
          errStr.contains('already accepted') ||
          errStr.contains('conflict')) {
        final api = ref.read(bloodHubApiServiceProvider);
        final resolvedId = await api.resolveJourneyIdFromRequestId(reqIdInt);
        if (!mounted) return;
        ref.invalidate(journeyDetailProvider(resolvedId));
        context.push('/journeys/$resolvedId');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not accept request: $e',
            style: const TextStyle(fontFamily: 'Inter', color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAcceptingRequestId = null);
      }
    }
  }

  Future<void> _fetchServerNotifications() async {
    try {
      final res = await _apiClient.get('notifications/');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _serverNotifications = data
                .whereType<Map<String, dynamic>>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        }
      }
      // Also mark as read on server and locally
      await ref.read(notificationCountProvider.notifier).markAsRead();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBoxOpen = Hive.isBoxOpen('notifications_box');

    final List<String> filters = [
      l10n?.notifTabFeed ?? 'Feed',
      l10n?.notifTabRequest ?? 'Request',
      l10n?.notifTabMessages ?? 'Messages',
      l10n?.notifTabProfile ?? 'Profile',
    ];

    final bool showWebPushHint = kIsWeb && FcmService.instance.isWebPushDeniedOrUnsupported;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/feed');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F7),
        appBar: BloodPulseAppBar(
          subtitle: l10n?.notifTitle ?? 'Notifications',
          showBackButton: true,
          onBack: () => context.pop(),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.notifTitle ?? 'Notification Center',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Real-time alerts for donor requests, community feed, messages, and profile milestones.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.neutral,
                ),
              ),
              const SizedBox(height: 12),

              // Web Push Fallback Inline Hint (No icons)
              if (showWebPushHint) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3F3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE6BDBA)),
                  ),
                  child: const Text(
                    "Push notifications are disabled or unsupported in this browser. You'll still see live alerts right here in the app.",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF7A4A4A),
                      height: 1.3,
                    ),
                  ),
                ),
              ],

              // ── 4 Filter Categories: Feed, Request, Messages, Profile ───────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(filters.length, (index) {
                    final isSelected = index == _selectedFilterIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filters[index]),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: const Color(0xFFFFF0F1),
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilterIndex = index);
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // ── Notification Items List ─────────────────────────────────────
              Expanded(
                child: isBoxOpen
                    ? ValueListenableBuilder<Box>(
                        valueListenable: Hive.box('notifications_box').listenable(),
                        builder: (context, box, _) {
                          return _buildNotificationList(box);
                        },
                      )
                    : _buildNotificationList(null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(Box? box) {
    if (_selectedFilterIndex == 2) {
      final cachedWidgets = _getCombinedNotificationWidgets(box);
      return _buildMessagesTab(cachedWidgets);
    }

    final widgets = _getCombinedNotificationWidgets(box);

    if (widgets.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No notifications yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchServerNotifications,
      color: AppColors.primary,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: widgets,
      ),
    );
  }

  List<Widget> _getCombinedNotificationWidgets(Box? box) {
    final List<Widget> widgets = [];
    final Set<String> seenIdentifiers = {};

    // 1. Process server notifications first
    for (final raw in _serverNotifications) {
      final notifId = raw['id']?.toString() ?? '';
      final title = raw['title']?.toString() ?? 'BloodPulse Alert';
      final body = raw['body']?.toString() ?? '';
      final type = raw['type']?.toString().toUpperCase() ?? 'GENERAL';
      final timestampStr = raw['created_at']?.toString();
      final isRead = raw['is_read'] == true;
      final requestId = raw['request_id'] != null ? raw['request_id'].toString() : _extractRequestId(body);
      final targetRoute = raw['target_route']?.toString();

      final dedupKey = '$type-$notifId-$title';
      if (seenIdentifiers.contains(dedupKey)) continue;
      seenIdentifiers.add(dedupKey);

      if (!_matchesFilter(type)) continue;

      widgets.add(_buildNotificationCard(
        title: title,
        body: body,
        type: type,
        timestampStr: timestampStr,
        isRead: isRead,
        requestId: requestId,
        targetRoute: targetRoute,
        rawData: raw,
      ));
    }

    // 2. Supplement with Hive offline notifications
    if (box != null && box.isNotEmpty) {
      final total = box.length;
      for (int i = total - 1; i >= 0; i--) {
        final raw = box.getAt(i);
        if (raw is! Map) continue;

        final title = raw['title']?.toString() ?? 'BloodPulse Alert';
        final body = raw['body']?.toString() ?? '';
        final type = raw['type']?.toString().toUpperCase() ?? 'GENERAL';
        final timestampStr = raw['timestamp']?.toString();
        final isRead = raw['is_read'] == true;
        final requestId = raw['request_id']?.toString() ?? _extractRequestId(body);
        final targetRoute = raw['target_route']?.toString();

        final dedupKey = '$type-$title';
        if (seenIdentifiers.contains(dedupKey)) continue;
        seenIdentifiers.add(dedupKey);

        if (!_matchesFilter(type)) continue;

        widgets.add(_buildNotificationCard(
          title: title,
          body: body,
          type: type,
          timestampStr: timestampStr,
          isRead: isRead,
          requestId: requestId,
          targetRoute: targetRoute,
          rawData: Map<String, dynamic>.from(raw),
        ));
      }
    }

    return widgets;
  }

  bool _matchesFilter(String type) {
    if (_selectedFilterIndex == 0) {
      return type.contains('FEED') || type.contains('POST') || type.contains('LIKE') || type.contains('COMMENT') || type.contains('SOCIAL');
    } else if (_selectedFilterIndex == 1) {
      return type.contains('REQUEST') || type.contains('EMERGENCY') || type.contains('MATCH') || type.contains('BLOOD') || type.contains('STANDBY') || type == 'GENERAL';
    } else if (_selectedFilterIndex == 2) {
      return type.contains('CHAT') || type.contains('MESSAGE');
    } else if (_selectedFilterIndex == 3) {
      return type.contains('PROFILE') || type.contains('VERIF') || type.contains('COOLDOWN') || type.contains('THANKS') || type.contains('CONFIRM') || type.contains('GUIDE');
    }
    return true;
  }

  String? _extractRequestId(String text) {
    final regExp = RegExp(r'\[Req #?(\d+)\]|request #?(\d+)', caseSensitive: false);
    final match = regExp.firstMatch(text);
    if (match != null) {
      return match.group(1) ?? match.group(2);
    }
    return null;
  }

  Widget _buildNotificationCard({
    required String title,
    required String body,
    required String type,
    String? timestampStr,
    required bool isRead,
    String? requestId,
    String? targetRoute,
    required Map<String, dynamic> rawData,
  }) {
    final timeText = _formatRelativeTime(timestampStr != null ? DateTime.tryParse(timestampStr) : null);
    final bool isEmergency = type.contains('EMERGENCY') || type.contains('REQUEST') || type == 'EMERGENCY_REQUEST_NEW';

    if (isEmergency) {
      return _buildEmergencyCard(
        title: title,
        body: body,
        timeText: timeText,
        isRead: isRead,
        requestId: requestId,
        rawData: rawData,
      );
    }

    return _buildStandardCard(
      title: title,
      body: body,
      type: type,
      timeText: timeText,
      isRead: isRead,
      targetRoute: targetRoute,
      rawData: rawData,
    );
  }

  /// Emergency Card matching Stitch UI:
  /// - White round card on soft pink background
  /// - Red "Urgent:" prefix, then hospital/ward needs blood group blood
  /// - Relative time ("12 mins ago")
  /// - Two buttons: "Respond" (dark red filled #C30121) and "Message" (outlined)
  Widget _buildEmergencyCard({
    required String title,
    required String body,
    required String timeText,
    required bool isRead,
    String? requestId,
    required Map<String, dynamic> rawData,
  }) {
    // Clean up body for display: remove [Req #...] internal tag if present
    final cleanBody = body.replaceAll(RegExp(r'\s*\[Req #?\d+\]'), '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Optional circular red icon on the left
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Urgent: ',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: cleanBody.isNotEmpty ? cleanBody : title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two Buttons: Respond (filled #C30121) + Message (outlined) — Guaranteed no clip/wrap
          Row(
            children: [
              // Respond button with ECG loading & auto-scaling
              Expanded(
                child: PressableScale(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        alignment: Alignment.center,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      onPressed: _isAcceptingRequestId == requestId
                          ? null
                          : () => _handleRespond(requestId, rawData),
                      child: _isAcceptingRequestId == requestId
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: EcgLoader(color: Colors.white, width: 24, height: 16),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Respond',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Message button with auto-scaling
              Expanded(
                child: PressableScale(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        alignment: Alignment.center,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      onPressed: (rawData['chat_room_id'] != null || requestId != null)
                          ? () {
                              final chatRoomId = rawData['chat_room_id']?.toString() ??
                                  (requestId != null ? 'emergency_$requestId' : null);
                              final recipientId = rawData['requester_id']?.toString() ??
                                  rawData['recipientId']?.toString();
                              if (chatRoomId != null) {
                                context.push('/chat', extra: {
                                  'chatRecipientName': rawData['requester_name']?.toString() ?? 'Blood Requester',
                                  'bloodGroup': rawData['blood_group']?.toString() ?? 'Blood',
                                  'chatRoomId': chatRoomId,
                                  'recipientId': recipientId ?? chatRoomId,
                                });
                              }
                            }
                          : null,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Message',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Standard Notification Card with full-width action button when target exists.
  Widget _buildStandardCard({
    required String title,
    required String body,
    required String type,
    required String timeText,
    required bool isRead,
    String? targetRoute,
    required Map<String, dynamic> rawData,
  }) {
    IconData icon = Icons.notifications_active_rounded;
    Color iconColor = AppColors.primary;
    String? buttonLabel;
    VoidCallback? buttonAction;

    if (type.contains('CHAT')) {
      icon = Icons.chat_bubble_rounded;
      iconColor = AppColors.tertiary;
    } else if (type.contains('FEED') || type.contains('LIKE') || type.contains('COMMENT')) {
      icon = Icons.favorite_rounded;
      iconColor = AppColors.primary;
      buttonLabel = 'View Post';
      buttonAction = () => context.go('/feed');
    } else if (type.contains('VERIF') || type.contains('CONFIRM')) {
      icon = Icons.verified_user_rounded;
      iconColor = AppColors.success;
      buttonLabel = 'View Details';
      buttonAction = () => context.go('/profile');
    } else if (type.contains('JOURNEY') || type.contains('TRACKING') || type.contains('STANDBY')) {
      icon = Icons.route_rounded;
      iconColor = AppColors.primary;
      buttonLabel = 'View Journey';
      final jId = rawData['journey_id'] ?? rawData['match_id'] ?? 1;
      buttonAction = () => context.push('/journeys/$jId');
    } else if (type.contains('THANKS')) {
      icon = Icons.favorite_rounded;
      iconColor = AppColors.primary;
      buttonLabel = 'View Letter';
      buttonAction = () => context.push('/blood-hub/thanks', extra: {'matchId': rawData['match_id'] ?? 1});
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.neutral,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
          if (buttonLabel != null && buttonAction != null) ...[
            const SizedBox(height: 12),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  onPressed: buttonAction,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessagesTab(List<Widget> cachedWidgets) {
    final user = ref.watch(authProvider).user;
    String currentUserId = '';
    try {
      currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {}
    if (currentUserId.isEmpty) {
      currentUserId = user?.primaryPhone ?? '';
    }

    if (currentUserId.isEmpty) {
      if (cachedWidgets.isNotEmpty) {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: cachedWidgets,
        );
      }
      return _buildEmptyMessagesState();
    }

    return StreamBuilder<List<ChatRoomSummary>>(
      stream: ChatService.instance.getUserChatRoomsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && cachedWidgets.isEmpty) {
          return const Center(child: AppLoader());
        }

        final rooms = snapshot.data ?? [];

        if (rooms.isEmpty && cachedWidgets.isEmpty) {
          return _buildEmptyMessagesState();
        }

        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ...cachedWidgets,
            ...rooms.map((room) {
              return _NotificationItemTile(
                icon: Icons.chat_bubble_rounded,
                iconColor: AppColors.tertiary,
                title: room.otherParticipantName.isNotEmpty
                    ? room.otherParticipantName
                    : 'Blood Donor (${room.otherParticipantBloodGroup})',
                subtitle: room.lastMessage.isNotEmpty
                    ? room.lastMessage
                    : 'Tap to open chat',
                time: _formatRelativeTime(room.updatedAt),
                isUnread: room.hasUnread,
                onTap: () {
                  context.push(
                    '/chat',
                    extra: {
                      'chatRecipientName': room.otherParticipantName.isNotEmpty
                          ? room.otherParticipantName
                          : 'Blood Donor',
                      'bloodGroup': room.otherParticipantBloodGroup.isNotEmpty
                          ? room.otherParticipantBloodGroup
                          : 'Blood Donor',
                      'chatRoomId': room.roomId,
                      'recipientId': room.otherParticipantId,
                    },
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyMessagesState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Conversations Yet',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When you connect with donors or recipients, your real conversations will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.neutral,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Recent';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _NotificationItemTile extends StatelessWidget {
  const _NotificationItemTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFFFF0F1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isUnread ? const Color(0xFFE6BDBA) : const Color(0xFFF0E0E0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withAlpha(20), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ),
                      Text(time, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.neutral)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

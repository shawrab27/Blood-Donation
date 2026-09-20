import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../models/chat_message_model.dart';
import '../../../../services/chat_service.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import 'notification_wallpaper_overlay.dart';

/// Notification Center Screen implementing the Notification Exception Rule.
///
/// Shows 4 notification filter categories:
///   1. Feed (Likes, comments, posts)
///   2. Request (Emergency blood request alerts)
///   3. Messages (P2P donor chats)
///   4. Profile (Cooldown countdown & badges)
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  int _selectedFilterIndex = 0; // 0: Feed, 1: Request, 2: Messages, 3: Profile

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

    return Scaffold(
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
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Real-time alerts for donor requests, community feed, messages, and profile milestones.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 16),

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
            const SizedBox(height: 20),

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
    );
  }

  Widget _buildNotificationList(Box? box) {
    final cachedWidgets = _getCachedNotificationWidgets(box);

    switch (_selectedFilterIndex) {
      case 0:
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ...cachedWidgets,
            const _NotificationItemTile(
              icon: Icons.favorite_rounded,
              iconColor: AppColors.primary,
              title: 'Rahim Ahmed liked your post',
              subtitle: '"Successfully donated 1 bag of AB+ blood today!"',
              time: '5 mins ago',
              isUnread: true,
            ),
            const _NotificationItemTile(
              icon: Icons.mode_comment_rounded,
              iconColor: AppColors.tertiary,
              title: 'Nusrat Jahan commented on your update',
              subtitle: '"Proud of you brother! Real hero 👏"',
              time: '40 mins ago',
              isUnread: false,
            ),
          ],
        );
      case 1:
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ...cachedWidgets,
            _NotificationItemTile(
              icon: Icons.emergency_rounded,
              iconColor: AppColors.primary,
              title: '🚨 CRITICAL MATCH: O+ Blood Needed',
              subtitle: 'Dhaka Medical College Hospital • 2 Bags required for surgery',
              time: '10 mins ago',
              isUnread: true,
              onTap: () => NotificationWallpaperOverlay.show(context),
            ),
            _NotificationItemTile(
              icon: Icons.water_drop_rounded,
              iconColor: AppColors.warning,
              title: '⚠️ Moderate Request: B+ Blood Needed',
              subtitle: 'Square Hospital, Panthapath • 1 Bag required in 24 hours',
              time: '2 hours ago',
              isUnread: false,
              onTap: () => NotificationWallpaperOverlay.show(context),
            ),
          ],
        );
      case 2:
        return _buildMessagesTab(cachedWidgets);
      case 3:
      default:
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ...cachedWidgets,
            const _NotificationItemTile(
              icon: Icons.verified_user_rounded,
              iconColor: AppColors.success,
              title: '🎉 NID & JIT Verification Approved',
              subtitle: 'Your profile has achieved 100% verified donor status.',
              time: 'Yesterday',
              isUnread: false,
            ),
            const _NotificationItemTile(
              icon: Icons.timelapse_rounded,
              iconColor: AppColors.tertiary,
              title: '⏳ Cooldown Countdown Update',
              subtitle: '42 days remaining until your next eligible donation date.',
              time: '2 days ago',
              isUnread: false,
            ),
          ],
        );
    }
  }

  List<Widget> _getCachedNotificationWidgets(Box? box) {
    if (box == null || box.isEmpty) return [];

    final List<Widget> widgets = [];
    final total = box.length;

    // Read in reverse order so latest notifications appear first
    for (int i = total - 1; i >= 0; i--) {
      final raw = box.getAt(i);
      if (raw is! Map) continue;

      final title = raw['title']?.toString() ?? 'BloodPulse Alert';
      final body = raw['body']?.toString() ?? '';
      final type = raw['type']?.toString().toUpperCase() ?? 'GENERAL';
      final timestampStr = raw['timestamp']?.toString();
      final isRead = raw['is_read'] == true;

      // Match filter index: 0=Feed, 1=Request, 2=Messages, 3=Profile
      bool matches = false;
      if (_selectedFilterIndex == 0 && (type.contains('FEED') || type.contains('POST') || type.contains('SOCIAL'))) {
        matches = true;
      } else if (_selectedFilterIndex == 1 && (type.contains('REQUEST') || type.contains('EMERGENCY') || type.contains('MATCH') || type.contains('BLOOD'))) {
        matches = true;
      } else if (_selectedFilterIndex == 2 && (type.contains('CHAT') || type.contains('MESSAGE'))) {
        matches = true;
      } else if (_selectedFilterIndex == 3 && (type.contains('PROFILE') || type.contains('VERIF') || type.contains('COOLDOWN'))) {
        matches = true;
      } else if (type == 'GENERAL' && _selectedFilterIndex == 1) {
        // Default general alerts to requests hub
        matches = true;
      }

      if (!matches) continue;

      IconData icon = Icons.notifications_active_rounded;
      Color iconColor = AppColors.primary;
      if (type.contains('CHAT')) {
        icon = Icons.chat_bubble_rounded;
        iconColor = AppColors.tertiary;
      } else if (type.contains('FEED')) {
        icon = Icons.favorite_rounded;
        iconColor = AppColors.primary;
      } else if (type.contains('VERIF')) {
        icon = Icons.verified_user_rounded;
        iconColor = AppColors.success;
      }

      String timeText = 'Recent';
      if (timestampStr != null) {
        try {
          final dt = DateTime.parse(timestampStr);
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 1) {
            timeText = 'Just now';
          } else if (diff.inMinutes < 60) {
            timeText = '${diff.inMinutes}m ago';
          } else if (diff.inHours < 24) {
            timeText = '${diff.inHours}h ago';
          } else {
            timeText = '${diff.inDays}d ago';
          }
        } catch (_) {}
      }

      final boxIndex = i;
      widgets.add(
        _NotificationItemTile(
          icon: icon,
          iconColor: iconColor,
          title: title,
          subtitle: body,
          time: timeText,
          isUnread: !isRead,
          onTap: () async {
            // Mark as read in Hive
            try {
              final updated = Map<String, dynamic>.from(raw);
              updated['is_read'] = true;
              await box.putAt(boxIndex, updated);
            } catch (_) {}

            if (!mounted) return;
            if (type.contains('CHAT')) {
              final senderName = raw['sender_name']?.toString() ??
                  raw['senderName']?.toString() ??
                  title.replaceAll('New message from ', '');
              final roomId = raw['chat_room_id']?.toString() ??
                  raw['chatRoomId']?.toString() ??
                  raw['room_id']?.toString() ??
                  'sarah_jenkins_o_minus';
              final bGroup = raw['blood_group']?.toString() ??
                  raw['bloodGroup']?.toString() ??
                  'O-';
              final rId = raw['sender_id']?.toString() ??
                  raw['senderId']?.toString() ??
                  raw['recipientId']?.toString() ??
                  roomId;
              context.push(
                '/chat',
                extra: {
                  'chatRecipientName': senderName,
                  'bloodGroup': bGroup,
                  'chatRoomId': roomId,
                  'recipientId': rId,
                },
              );
            } else if (type.contains('EMERGENCY')) {
              NotificationWallpaperOverlay.show(context);
            }
          },
        ),
      );
    }

    return widgets;
  }

  Widget _buildMessagesTab(List<Widget> cachedWidgets) {
    final user = ref.watch(authProvider).user;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
        user?.primaryPhone ??
        '';

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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isUnread ? const Color(0xFFE6BDBA) : Colors.grey.shade200),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import 'notification_wallpaper_overlay.dart';

/// Notification Center Screen implementing the Notification Exception Rule.
///
/// Shows 4 notification filter categories:
///   1. Feed (Likes, comments, posts)
///   2. Request (Emergency blood request alerts)
///   3. Messages (P2P donor chats)
///   4. Profile (Cooldown countdown & badges)
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  int _selectedFilterIndex = 0; // 0: Feed, 1: Request, 2: Messages, 3: Profile

  final List<String> _filters = ['Feed', 'Request', 'Messages', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Notifications',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Center',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary),
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
                children: List.generate(_filters.length, (index) {
                  final isSelected = index == _selectedFilterIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filters[index]),
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
              child: _buildNotificationList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList() {
    switch (_selectedFilterIndex) {
      case 0:
        return ListView(
          children: const [
            _NotificationItemTile(
              icon: Icons.favorite_rounded,
              iconColor: AppColors.primary,
              title: 'Rahim Ahmed liked your post',
              subtitle: '"Successfully donated 1 bag of AB+ blood today!"',
              time: '5 mins ago',
              isUnread: true,
            ),
            _NotificationItemTile(
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
          children: [
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
        return ListView(
          children: [
            _NotificationItemTile(
              icon: Icons.chat_bubble_rounded,
              iconColor: AppColors.tertiary,
              title: 'Dr. Alim (Transfusion Unit)',
              subtitle: '"Can you reach DMCH Gate 2 by 4:00 PM for verification?"',
              time: '15 mins ago',
              isUnread: true,
              onTap: () => context.push('/chat'),
            ),
            _NotificationItemTile(
              icon: Icons.person_search_rounded,
              iconColor: const Color(0xFF1B8A4E),
              title: 'Badhan DU Coordinator',
              subtitle: '"Thank you for accepting the voluntary dispatch request!"',
              time: '1 hour ago',
              isUnread: false,
              onTap: () => context.push('/chat'),
            ),
          ],
        );
      case 3:
      default:
        return ListView(
          children: const [
            _NotificationItemTile(
              icon: Icons.verified_user_rounded,
              iconColor: AppColors.success,
              title: '🎉 NID & JIT Verification Approved',
              subtitle: 'Your profile has achieved 100% verified donor status.',
              time: 'Yesterday',
              isUnread: false,
            ),
            _NotificationItemTile(
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

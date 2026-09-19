import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';
import 'profile_drawer.dart';
import '../../features/profile/domain/providers/profile_provider.dart';
import '../../features/notifications/domain/providers/notification_provider.dart';

/// Centralized, reusable Custom AppBar for BloodPulse.
///
/// Strictly enforces the BloodPulse UI Top Bar rules:
///   • Top-Left: Branded [BloodPulseLogo] or custom title with optional back button
///   • Top-Right:
///       1. Notification Bell icon with active red unread badge (#C30121)
///       2. Profile Avatar with red border (#C30121) navigating to /profile
class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Color? titleColor;
  final String? subtitle;
  final bool showLogo;
  final double logoSize;
  final bool showBackButton;
  final VoidCallback? onBack;
  final int? notificationCount;
  final bool showNotification;
  final VoidCallback? onNotificationTap;
  final bool showProfile;
  final bool showMenu;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool centerTitle;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.titleColor,
    this.subtitle,
    this.showLogo = true,
    this.logoSize = 32.0,
    this.showBackButton = false,
    this.onBack,
    this.notificationCount,
    this.showNotification = true,
    this.onNotificationTap,
    this.showProfile = true,
    this.showMenu = false,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        64.0 + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveUnreadCount = ref.watch(notificationCountProvider);
    final effectiveNotificationCount = notificationCount ?? liveUnreadCount;

    final profileAsync = ref.watch(profileProvider);
    String? avatarUrl;
    String? firstLetter;

    profileAsync.whenData((profile) {
      if (profile != null) {
        avatarUrl = profile.profilePicture;
        final name = profile.firstName?.isNotEmpty == true
            ? profile.firstName!
            : profile.username ?? '';
        firstLetter = name.isNotEmpty ? name[0].toUpperCase() : null;
      }
    });

    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      centerTitle: centerTitle,
      bottom: bottom,
      title: Row(
        children: [
          // ── Optional Back Button ──
          if (showBackButton) ...[
            GestureDetector(
              onTap: onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/feed');
                    }
                  },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (backgroundColor != null &&
                          backgroundColor!.computeLuminance() < 0.3)
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: (backgroundColor != null &&
                          backgroundColor!.computeLuminance() < 0.3)
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: (backgroundColor != null &&
                          backgroundColor!.computeLuminance() < 0.3)
                      ? Colors.white
                      : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // ── Left Title / Logo ──
          Expanded(
            child: titleWidget != null
                ? titleWidget!
                : (title != null && !showLogo)
                    ? Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor ?? AppColors.secondary,
                          letterSpacing: -0.3,
                        ),
                      )
                    : showLogo
                        ? BloodPulseLogo(
                            height: logoSize,
                            subtitle: showBackButton ? null : subtitle,
                            onTap: () {
                              if (context.mounted) {
                                context.go('/feed');
                              }
                            },
                          )
                        : Text(
                            title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: titleColor ?? AppColors.primary,
                            ),
                          ),
          ),
        ],
      ),
      actions: [
        ...?actions,

        // ── 1. Notification Bell with Badge Count ──
        if (showNotification)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.notifications_outlined,
                  color: (backgroundColor != null &&
                          backgroundColor!.computeLuminance() < 0.3)
                      ? Colors.white
                      : AppColors.secondary,
                  size: 22,
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  ref.read(notificationCountProvider.notifier).markAsRead();
                  if (onNotificationTap != null) {
                    onNotificationTap!();
                  } else {
                    context.push('/notifications');
                  }
                },
              ),
              if (effectiveNotificationCount > 0)
                Positioned(
                  right: 4,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        effectiveNotificationCount > 99 ? '99+' : '$effectiveNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

        // ── 2. Profile Avatar ──
        if (showProfile)
          GestureDetector(
            onTap: () => ProfileDrawer.show(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _TopBarProfileAvatar(
                avatarUrl: avatarUrl,
                firstLetter: firstLetter,
              ),
            ),
          ),
        const SizedBox(width: 6),

        // ── 3. Menu Options (3-Dot Popup Menu) ──
        if (showMenu)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: (backgroundColor != null &&
                      backgroundColor!.computeLuminance() < 0.3)
                  ? Colors.white
                  : AppColors.secondary,
              size: 22,
            ),
            tooltip: 'More Options',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            color: Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  context.go('/profile');
                  break;
                case 'request':
                  context.go('/emergency-request');
                  break;
                case 'map':
                  context.go('/map');
                  break;
                case 'notifications':
                  context.push('/notifications');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 20, color: AppColors.secondary),
                    SizedBox(width: 10),
                    Text('My Profile', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'request',
                child: Row(
                  children: [
                    Icon(Icons.bloodtype_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Request Blood', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'map',
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 20, color: AppColors.secondary),
                    SizedBox(width: 10),
                    Text('Live Donor Map', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined, size: 20, color: AppColors.secondary),
                    SizedBox(width: 10),
                    Text('Notifications', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),

        const SizedBox(width: 8),
      ],
    );
  }
}

class _TopBarProfileAvatar extends StatelessWidget {
  const _TopBarProfileAvatar({this.avatarUrl, this.firstLetter});
  final String? avatarUrl;
  final String? firstLetter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        color: const Color(0xFFF3DDE0),
      ),
      child: ClipOval(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackLetter(),
      );
    }
    return _fallbackLetter();
  }

  Widget _fallbackLetter() {
    if (firstLetter != null && firstLetter!.isNotEmpty) {
      return Center(
        child: Text(
          firstLetter!,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'Inter',
          ),
        ),
      );
    }
    return const Icon(
      Icons.person_rounded,
      color: AppColors.primary,
      size: 20,
    );
  }
}

/// Backward compatibility alias for [CustomAppBar].
typedef BloodPulseAppBar = CustomAppBar;

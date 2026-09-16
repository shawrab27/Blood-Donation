import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'app_logo_slot.dart';
import '../../features/profile/domain/providers/profile_provider.dart';

class BloodPulseAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const BloodPulseAppBar({
    super.key,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.onNotificationTap,
    this.logoSize = AppLogoSize.header,
    this.showLogo = true,
  });

  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onNotificationTap;
  final double logoSize;
  final bool showLogo;

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.secondary),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (showLogo) ...[
            AppLogoSlot(size: logoSize),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BloodPulse',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: -0.3),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.neutral)),
              ],
            ),
          ] else ...[
            Text(
              subtitle ?? 'BloodPulse',
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary, letterSpacing: -0.3),
            ),
          ],
        ],
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.secondary, size: 24),
              onPressed: () {
                if (onNotificationTap != null) {
                  onNotificationTap!();
                } else {
                  context.push('/notifications');
                }
              },
            ),
            Positioned(
              right: 10,
              top: 12,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ProfileAvatar(avatarUrl: avatarUrl, firstLetter: firstLetter),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.avatarUrl, this.firstLetter});
  final String? avatarUrl;
  final String? firstLetter;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'profile_avatar_hero',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
          color: const Color(0xFFF3DDE0),
        ),
        child: ClipOval(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(avatarUrl!, fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => _letterOrIcon());
    }
    return _letterOrIcon();
  }

  Widget _letterOrIcon() {
    if (firstLetter != null) {
      return Center(
        child: Text(firstLetter!,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
      );
    }
    return const Icon(Icons.person_rounded, color: AppColors.primary, size: 20);
  }
}

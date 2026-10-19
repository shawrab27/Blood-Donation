// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/domain/providers/profile_provider.dart';
import '../../features/profile/presentation/widgets/drawer/profile_drawer_header.dart';
import '../../features/profile/presentation/widgets/drawer/profile_drawer_hero_card.dart';
import '../../features/profile/presentation/widgets/drawer/profile_drawer_theme_selector.dart';
import '../../features/profile/presentation/widgets/drawer/profile_drawer_menu_list.dart';
import '../../features/profile/presentation/widgets/modals/logout_confirmation_modal.dart';

/// 1:1 Parity with Stitch Screen 4 (Notification Profile Slidebar / Drawer).
/// High-fidelity top-right aligned profile slidebar popup card with frosted glass
/// background blur, cropped cleanly after the Log Out button, and smooth popup animation.
class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  /// Smooth popup animation with background blur matching Stitch Screen 4.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Profile Drawer',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final blurSigma = (animation.value * 8.0).clamp(0.001, 8.0);

        return Stack(
          children: [
            // Frosted glass background blur over the entire screen behind the slidebar
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: const SizedBox.expand(),
              ),
            ),

            // Profile Slidebar Floating Card pinned to Top-Right below status bar
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10, left: 16),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                    child: ScaleTransition(
                      alignment: Alignment.topRight,
                      scale: Tween<double>(begin: 0.88, end: 1.0).animate(curvedAnimation),
                      child: const ProfileDrawer(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileData = ref.watch(profileProvider.select((p) => p.value));
    final authUser = ref.watch(authProvider.select((a) => a.user));

    String displayName = 'Guest User';
    final Uint8List? avatarBytes = authUser?.avatarBytes;
    String? photoUrl = authUser?.photoUrl ?? profileData?.profilePicture;
    if (photoUrl != null && !photoUrl.startsWith('http')) {
      photoUrl = ApiClient.defaultBaseUrl + photoUrl;
    }
    final String? googlePhotoUrl = authUser?.googlePhotoUrl;

    final pName = '${profileData?.firstName ?? ''} ${profileData?.lastName ?? ''}'.trim();
    final aName = authUser?.fullName.trim() ?? '';
    final name = pName.isNotEmpty ? pName : (aName.isNotEmpty ? aName : 'Donor User');

    if (name.isNotEmpty && name != 'Donor User') {
      displayName = name;
    }

    final mediaQuery = MediaQuery.of(context);
    final double dialogWidth = (mediaQuery.size.width * 0.88).clamp(300.0, 350.0);
    final double maxDialogHeight = mediaQuery.size.height * 0.88;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFF3DDE0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Branded Header (No divider line below it matching Stitch UI)
                ProfileDrawerHeader(onClose: () => Navigator.of(context).pop()),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Burgundy Identity Hero Card
                      ProfileDrawerHeroCard(
                        displayName: displayName,
                        avatarBytes: avatarBytes,
                        googlePhotoUrl: googlePhotoUrl,
                        photoUrl: photoUrl,
                        onViewProfile: () {
                          Navigator.of(context).pop();
                          context.go('/profile');
                        },
                      ),
                      const SizedBox(height: 12),

                      // Appearance Theme Selector
                      const ProfileDrawerThemeSelector(),
                      const SizedBox(height: 12),

                      // Preferences Navigation Menu
                      const ProfileDrawerMenuList(),
                      const SizedBox(height: 16),

                      // Log Out CTA (Pill Button wired to LogoutConfirmationModal)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC30121),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            LogoutConfirmationModal.show(context, ref);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

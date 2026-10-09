// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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
/// Modularized architecture with <300 lines per file.
class ProfileDrawer extends ConsumerWidget {
  const ProfileDrawer({super.key});

  /// Smooth slide-in from the right edge with backdrop blur.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Profile Drawer',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Align(
          alignment: Alignment.centerRight,
          child: ProfileDrawer(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
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

    final double drawerWidth = (MediaQuery.of(context).size.width * 0.84).clamp(300.0, 340.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8F7),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(-4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Branded Header
              ProfileDrawerHeader(onClose: () => Navigator.of(context).pop()),
              const Divider(height: 1, color: Color(0xFFF3DDE0)),

              // Scrollable Menu Body
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC30121),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 15),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

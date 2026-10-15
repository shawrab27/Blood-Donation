// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../profile/domain/providers/profile_provider.dart';
import '../widgets/settings_user_card.dart';
import '../widgets/settings_options_card.dart';
import '../widgets/settings_account_actions_card.dart';

/// Settings & Security Screen for BloodPulse.
/// 1:1 Parity with Stitch Screen 5. Modular architecture under 300 lines.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final authState = ref.watch(authProvider);

    final authUser = authState.user;
    final Uint8List? avatarBytes = authUser?.avatarBytes;
    String? photoUrl = authUser?.photoUrl;
    String displayName = authUser?.fullName.trim().isNotEmpty == true
        ? authUser!.fullName
        : 'Blood Donor';
    String bloodGroup = authUser?.bloodGroup.isNotEmpty == true ? authUser!.bloodGroup : 'O+';
    int totalDonations = authUser?.totalBagsDonated ?? 0;

    profileAsync.whenData((p) {
      if (p != null) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        if (name.isNotEmpty && name != 'Dr. S. M. Shawrab') {
          displayName = name;
        }
        if (p.bloodGroup != null && p.bloodGroup!.isNotEmpty) {
          bloodGroup = p.bloodGroup!;
        }
        if (p.totalBagsDonated > 0) {
          totalDonations = p.totalBagsDonated;
        }
        if (p.profilePicture != null && p.profilePicture!.isNotEmpty) {
          photoUrl = p.profilePicture;
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF24191A)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/feed');
            }
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0015),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF3DDE0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/images/launcher_icon_transparent.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveCenterWrapper(
        maxWidth: 540,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Donor Snapshot Card
            SettingsUserCard(
              displayName: displayName,
              bloodGroup: bloodGroup,
              totalDonations: totalDonations,
              avatarBytes: avatarBytes,
              photoUrl: photoUrl,
              googlePhotoUrl: authUser?.googlePhotoUrl,
            ),
            const SizedBox(height: 16),

            // Primary Settings Options Card (Language, Notification, PulseAI, Privacy, Rate, Share, Learn, Contact)
            const SettingsOptionsCard(),
            const SizedBox(height: 16),

            // Account & Danger Actions Card (Create Account, Delete Account, Logout)
            const SettingsAccountActionsCard(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

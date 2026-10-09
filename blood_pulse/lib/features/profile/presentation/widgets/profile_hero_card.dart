// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/avatar_helper.dart';

/// Stitch Screen 1: User Profile Hero Card
/// Features avatar with camera badge, Platinum donor badge, editable bio,
/// blood group pill, and Admin-locked blood group disclosure banner.
class ProfileHeroCard extends StatelessWidget {
  final String displayName;
  final String bio;
  final String bloodGroup;
  final int totalDonations;
  final Uint8List? avatarBytes;
  final String? photoUrl;
  final String? googlePhotoUrl;
  final VoidCallback onPickPhoto;
  final VoidCallback onEditBio;

  const ProfileHeroCard({
    super.key,
    required this.displayName,
    required this.bio,
    required this.bloodGroup,
    required this.totalDonations,
    this.avatarBytes,
    this.photoUrl,
    this.googlePhotoUrl,
    required this.onPickPhoto,
    required this.onEditBio,
  });

  String get _tierName {
    if (totalDonations >= 10) return 'Platinum Donor';
    if (totalDonations >= 5) return 'Gold Donor';
    if (totalDonations >= 2) return 'Silver Donor';
    return 'Active Donor';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar Stack with Badges & Edit Button
          Stack(
            alignment: Alignment.center,
            children: [
              // Main Avatar
              GestureDetector(
                onTap: onPickPhoto,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                  child: Stack(
                    children: [
                      AvatarHelper(
                        radius: 46,
                        fallbackName: displayName,
                        uploadedPhoto: avatarBytes,
                        serverPhotoUrl: photoUrl,
                        googlePhotoUrl: googlePhotoUrl,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Right Edit Profile Button
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE9EB),
                    padding: const EdgeInsets.all(8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.push('/edit-profile'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // User Name
          Text(
            displayName,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF24191A),
            ),
          ),
          const SizedBox(height: 4),

          // Bio Quote with Tap to Edit
          GestureDetector(
            onTap: onEditBio,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '"$bio"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF5F5E5E),
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Badge Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1E4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFF001D35)),
                    const SizedBox(width: 4),
                    Text(
                      _tierName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001D35),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$bloodGroup Blood',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Admin-Locked Blood Group Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD8A8)),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🔒 Note: Blood Group can ONLY be edited by an Admin for biological safety.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

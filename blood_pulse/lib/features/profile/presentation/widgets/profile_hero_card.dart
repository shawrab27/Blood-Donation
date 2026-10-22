// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/avatar_helper.dart';

/// Stitch Screen 1: Profile Hero Section
/// 1:1 match to Stitch design:
/// - 176px circle photo with 5px solid red border (#C30121)
/// - Frosted glass blood group pill inside bottom (8px from bottom)
/// - Rank capsule at upper-right (-top-1, -right-2)
/// - Georgia name (22px bold), Inter italic bio (max 120 chars)
/// - 180x44px pill 'Edit Profile' button
/// - Admin-locked blood group disclosure
class ProfileHeroCard extends StatelessWidget {
  final String displayName;
  final String bio;
  final String bloodGroup;
  final int totalDonations;
  final int rank;
  final String? donorTitle;
  final String? occupation;
  final String? positionDisplay;
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
    this.rank = 0,
    this.donorTitle,
    this.occupation,
    this.positionDisplay,
    this.avatarBytes,
    this.photoUrl,
    this.googlePhotoUrl,
    required this.onPickPhoto,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    final String rankText;
    if (totalDonations == 0) {
      rankText = 'New Member';
    } else if (rank > 0) {
      rankText = 'Rank #$rank';
    } else {
      rankText = donorTitle ?? 'Active';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 176px Avatar Circle Stack ──
          SizedBox(
            width: 176,
            height: 176,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 5px Solid Red Ring + Cover Photo
                GestureDetector(
                  onTap: onPickPhoto,
                  child: Container(
                    width: 176,
                    height: 176,
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFC30121),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33C30121),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFF0F1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AvatarHelper(
                            radius: 80,
                            fallbackName: displayName,
                            uploadedPhoto: avatarBytes,
                            serverPhotoUrl: photoUrl,
                            googlePhotoUrl: googlePhotoUrl,
                          ),
                          // Subtle camera overlay at bottom
                          Positioned(
                            bottom: 36,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Rank Capsule at 1:30 position (upper-right)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 76, minHeight: 26),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC30121),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      rankText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),

                // Frosted Glass Blood Group Pill (inside circle, 8px from bottom)
                Positioned(
                  bottom: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 72,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC30121).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          bloodGroup,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Name & Bio ──
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF24191A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // Title / Occupation / Position Display
          if (totalDonations == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  positionDisplay ?? (occupation != null && occupation!.isNotEmpty ? occupation! : 'New Member'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5F5E5E),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (donorTitle != null && donorTitle!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F1),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFFFFD1D6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.military_tech_rounded, size: 14, color: Color(0xFFC30121)),
                          const SizedBox(width: 4),
                          Text(
                            donorTitle!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC30121),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (occupation != null && occupation!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Text(
                        occupation!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5F5E5E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),

          GestureDetector(
            onTap: onEditBio,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                bio.isNotEmpty ? '"$bio"' : '"Committed voluntary donor across Bangladesh."',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF5F5E5E),
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Edit Profile Button ──
          SizedBox(
            width: 180,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/edit-profile'),
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFC30121)),
              label: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC30121),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC30121), width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          // USER RULE - do not change: Admin note hidden from normal profile view (shown only in Edit Profile when requesting change)
        ],
      ),
    );
  }
}

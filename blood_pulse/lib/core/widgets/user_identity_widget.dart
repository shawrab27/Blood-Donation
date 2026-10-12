// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Unified UserIdentity component used across Feed posts, comments,
/// blood requests, profile header, leaderboard, and certificates.
///
/// Ensures consistent presentation of donor name, clinical blood badge,
/// verification status, and avatar throughout BloodPulse.
class UserIdentityWidget extends StatelessWidget {
  final int? id;
  final String displayName;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final String? badge;
  final String? bloodGroup;
  final String? subtitle;
  final double avatarRadius;
  final VoidCallback? onTap;

  const UserIdentityWidget({
    super.key,
    this.id,
    required this.displayName,
    this.avatarUrl,
    this.avatarBytes,
    this.badge,
    this.bloodGroup,
    this.subtitle,
    this.avatarRadius = 18.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstLetter = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'D';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: const Color(0xFFFDE8E8),
                backgroundImage: avatarBytes != null
                    ? MemoryImage(avatarBytes!)
                    : (avatarUrl != null && avatarUrl!.startsWith('http'))
                        ? NetworkImage(avatarUrl!) as ImageProvider
                        : null,
                child: (avatarBytes == null && (avatarUrl == null || !avatarUrl!.startsWith('http')))
                    ? Text(
                        firstLetter,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: avatarRadius * 0.9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),

            // Name + Badge + Subtitle
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                      ),
                      if (bloodGroup != null && bloodGroup!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE8E8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            bloodGroup!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Subtitle & Badge row
                  if ((badge != null && badge!.isNotEmpty) || (subtitle != null && subtitle!.isNotEmpty)) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badge != null && badge!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _badgeBackgroundColor(badge!),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: _badgeTextColor(badge!),
                              ),
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            const SizedBox(width: 6),
                        ],
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Flexible(
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _badgeBackgroundColor(String badgeName) {
    final lower = badgeName.toLowerCase();
    if (lower.contains('legendary') || lower.contains('platinum')) {
      return const Color(0xFFEDE9FE);
    } else if (lower.contains('gold')) {
      return const Color(0xFFFEF3C7);
    } else if (lower.contains('officer') || lower.contains('staff')) {
      return const Color(0xFFE0F2FE);
    } else if (lower.contains('verified') || lower.contains('active')) {
      return const Color(0xFFDCFCE7);
    }
    return const Color(0xFFF1F5F9);
  }

  Color _badgeTextColor(String badgeName) {
    final lower = badgeName.toLowerCase();
    if (lower.contains('legendary') || lower.contains('platinum')) {
      return const Color(0xFF6D28D9);
    } else if (lower.contains('gold')) {
      return const Color(0xFFB45309);
    } else if (lower.contains('officer') || lower.contains('staff')) {
      return const Color(0xFF0369A1);
    } else if (lower.contains('verified') || lower.contains('active')) {
      return const Color(0xFF15803D);
    }
    return const Color(0xFF475569);
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blood_pulse/core/widgets/avatar_helper.dart';

/// Burgundy User Identity Hero Card in Profile Drawer matching Stitch Screen 4.
class ProfileDrawerHeroCard extends StatelessWidget {
  final String displayName;
  final Uint8List? avatarBytes;
  final String? googlePhotoUrl;
  final String? photoUrl;
  final VoidCallback onViewProfile;

  const ProfileDrawerHeroCard({
    super.key,
    required this.displayName,
    this.avatarBytes,
    this.googlePhotoUrl,
    this.photoUrl,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF850014),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF850014).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AvatarHelper(
            radius: 20,
            fallbackName: displayName,
            uploadedPhoto: avatarBytes,
            googlePhotoUrl: googlePhotoUrl,
            serverPhotoUrl: photoUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PressableScale(child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onViewProfile,
            child: const Text(
              'View Profile',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
            ),
          )),
        ],
      ),
    );
  }
}

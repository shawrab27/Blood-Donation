// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';

/// Modal bottom sheet providing multi-channel poster sharing options.
class PosterShareSheet extends StatelessWidget {
  const PosterShareSheet({
    super.key,
    required this.isBangla,
    required this.onSelectChannel,
  });

  final bool isBangla;
  final ValueChanged<String?> onSelectChannel;

  static void show(
    BuildContext context, {
    required bool isBangla,
    required ValueChanged<String?> onSelectChannel,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: PosterShareSheet(
          isBangla: isBangla,
          onSelectChannel: (platform) {
            Navigator.pop(ctx);
            onSelectChannel(platform);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isBangla ? 'পোস্টার শেয়ার করুন' : 'Share Emergency Poster',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _shareChannelBtn(
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () => onSelectChannel('whatsapp'),
              ),
              _shareChannelBtn(
                icon: Icons.sms_rounded,
                color: AppColors.tertiary,
                label: 'SMS',
                onTap: () => onSelectChannel('sms'),
              ),
              _shareChannelBtn(
                icon: Icons.share_rounded,
                color: AppColors.primary,
                label: isBangla ? 'অন্যান্য' : 'All Apps',
                onTap: () => onSelectChannel(null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareChannelBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

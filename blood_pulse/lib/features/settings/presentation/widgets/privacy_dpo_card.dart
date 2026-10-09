// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Copyable Data Protection Officer Chip in Privacy Policy Screen.
class PrivacyDpoCard extends StatelessWidget {
  const PrivacyDpoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6BDBA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Protection Officer & Inquiries',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'For inquiries regarding medical data privacy or to exercise erasure rights:',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5C3F3D)),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'privacy@bloodpulse.health'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Copied privacy@bloodpulse.health to clipboard'),
                  backgroundColor: Color(0xFF1B8A4E),
                ),
              );
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'privacy@bloodpulse.health',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

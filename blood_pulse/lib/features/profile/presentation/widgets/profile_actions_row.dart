// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Stitch Screen 1: Quick Action Pills
/// Features "Update Date" datepicker trigger, "Emergency" requisition route,
/// and "Download Verified Digital Certificate" download trigger.
class ProfileActionsRow extends StatelessWidget {
  final VoidCallback onUpdateDate;
  final VoidCallback onDownloadCertificate;

  const ProfileActionsRow({
    super.key,
    required this.onUpdateDate,
    required this.onDownloadCertificate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Dual Quick Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primary),
                label: const Text('Update Date'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF24191A),
                  side: const BorderSide(color: Color(0xFFE6BDBA)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: onUpdateDate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.emergency_rounded, size: 16, color: AppColors.primary),
                label: const Text('Emergency'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.3),
                  backgroundColor: const Color(0xFFFFF0F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  context.push('/blood-hub/personal-emergency');
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Full Width Certificate CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text('Download Verified Digital Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 0,
              side: const BorderSide(color: Color(0xFFE6BDBA)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: onDownloadCertificate,
          ),
        ),
      ],
    );
  }
}

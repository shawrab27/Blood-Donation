// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../core/theme/app_colors.dart';

/// Modal bottom sheet displaying the Verified Digital Donor Certificate.
class DigitalCertificateSheet extends StatelessWidget {
  final String donorName;
  final String bloodGroup;
  final int totalDonations;

  const DigitalCertificateSheet({
    super.key,
    required this.donorName,
    required this.bloodGroup,
    required this.totalDonations,
  });

  static Future<void> show({
    required BuildContext context,
    required String donorName,
    required String bloodGroup,
    required int totalDonations,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DigitalCertificateSheet(
        donorName: donorName,
        bloodGroup: bloodGroup,
        totalDonations: totalDonations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Digital Donor Certificate',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Certificate Frame wrapped in RepaintBoundary for capture and sharing
          RepaintBoundary(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.primary, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'CERTIFICATE OF RECOGNITION',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    donorName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Donations completed: $totalDonations (Blood Group: $bloodGroup).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF444444),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'BloodPulse Verified Donor • Tier ${totalDonations >= 10 ? "Platinum" : totalDonations >= 5 ? "Gold" : "Silver"}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Share CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share Certificate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Donations completed: $totalDonations on BloodPulse.\n'
                        'Blood group: $bloodGroup. Verified voluntary donor: https://bloodpulse.org',
                    subject: '$donorName - BloodPulse Donor Certificate',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

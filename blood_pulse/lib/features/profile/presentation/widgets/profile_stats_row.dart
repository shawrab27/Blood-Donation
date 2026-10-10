// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Stitch Screen 1: Profile Stats Row
/// Features Total Bags Donated card alongside Next Donation circular progress ring.
class ProfileStatsRow extends StatelessWidget {
  final int totalBags;
  final int daysRemaining;
  final double progressPercent;
  final bool showCountdown;

  const ProfileStatsRow({
    super.key,
    required this.totalBags,
    required this.daysRemaining,
    required this.progressPercent,
    this.showCountdown = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEligible = daysRemaining <= 0;

    return Row(
      children: [
        // ── Total Bags Donated Card ──
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL BAGS\nDONATED',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$totalBags',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Bags',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (showCountdown) ...[
          const SizedBox(width: 12),

          // ── Next Donation Countdown Card ──
          Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'NEXT DONATION',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: isEligible ? 1.0 : progressPercent.clamp(0.05, 1.0),
                        strokeWidth: 5.5,
                        backgroundColor: const Color(0xFFFEE9EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isEligible ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isEligible ? 'NOW' : '${daysRemaining}d',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: isEligible ? 13 : 15,
                              fontWeight: FontWeight.bold,
                              color: isEligible ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
  }
}

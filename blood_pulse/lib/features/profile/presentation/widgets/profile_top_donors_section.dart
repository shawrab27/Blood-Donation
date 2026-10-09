// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Stitch Screen 1: Top Donors leaderboard horizontal row
/// Shows Global Rank badge along with top active donor community avatars.
class ProfileTopDonorsSection extends StatelessWidget {
  const ProfileTopDonorsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final topDonors = [
      {'name': 'Mark R.', 'rank': 1, 'bags': 14, 'color': const Color(0xFFFFD700)},
      {'name': 'Sara T.', 'rank': 2, 'bags': 12, 'color': const Color(0xFFC0C0C0)},
      {'name': 'David K.', 'rank': 3, 'bags': 11, 'color': const Color(0xFFCD7F32)},
      {'name': 'Elena M.', 'rank': 4, 'bags': 10, 'color': AppColors.primary},
      {'name': 'Tariq A.', 'rank': 5, 'bags': 9, 'color': AppColors.primary},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Donors',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6BDBA)),
                ),
                child: const Text(
                  'Global Rank #3',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal scroll of top donors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: topDonors.map((donor) {
                final rank = donor['rank'] as int;
                final name = donor['name'] as String;
                final bags = donor['bags'] as int;
                final color = donor['color'] as Color;

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Text(
                              name[0],
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color == const Color(0xFFFFD700) ? const Color(0xFFB45309) : color,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              '$rank',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF24191A),
                        ),
                      ),
                      Text(
                        '$bags Bags',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

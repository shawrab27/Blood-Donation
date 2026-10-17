// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stitch Screen 1: Rating + XP Section (Two Equal Cards, 104px High)
/// 1:1 match to Stitch:
/// - Left Card: Rating (average / 5, 5 blood drop icons, total reviews)
/// - Right Card: XP (current XP, 8px progress bar, level & badge tier)
class ProfileRatingXpCard extends StatelessWidget {
  final double ratingAvg;
  final int ratingCount;
  final int xp;
  final int level;
  final double levelProgress;
  final String tier;
  final int totalDonations;
  final String? donorTitle;
  final VoidCallback? onTapRating;
  final VoidCallback? onTapXp;

  const ProfileRatingXpCard({
    super.key,
    required this.ratingAvg,
    required this.ratingCount,
    required this.xp,
    required this.level,
    required this.levelProgress,
    required this.tier,
    this.totalDonations = 0,
    this.donorTitle,
    this.onTapRating,
    this.onTapXp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left Card: Rating ──
        Expanded(
          child: InkWell(
            onTap: () {
              if (onTapRating != null) {
                onTapRating!();
              } else {
                context.push('/profile/reviews');
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Rating',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5F5E5E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                totalDonations == 0
                                    ? '--'
                                    : (ratingAvg > 0 ? ratingAvg.toStringAsFixed(1) : '5.0'),
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF24191A),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                '/ 5',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF5F5E5E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5 Blood drop icons
                  Row(
                    children: List.generate(5, (index) {
                      if (totalDonations == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.water_drop_outlined,
                            size: 16,
                            color: Color(0xFFE2D6D6),
                          ),
                        );
                      }
                      final double dropValue = (ratingAvg - index).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          dropValue >= 0.5 ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                          size: 16,
                          color: dropValue >= 0.5 ? const Color(0xFFC30121) : const Color(0xFFE2D6D6),
                        ),
                      );
                    }),
                  ),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      totalDonations == 0
                          ? 'No reviews yet'
                          : (ratingCount > 0 ? '$ratingCount reviews' : 'New verified donor'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF5F5E5E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Right Card: XP ──
        Expanded(
          child: InkWell(
            onTap: () {
              if (onTapXp != null) {
                onTapXp!();
              } else {
                context.push('/profile/xp');
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0E5E5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'XP',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5F5E5E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                totalDonations == 0 ? '0' : '$xp',
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC30121),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'XP',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC30121),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 8px progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      height: 8,
                      color: const Color(0xFFF3DDE0),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: totalDonations == 0 ? 0.0 : levelProgress.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFC30121),
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                  ),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      totalDonations == 0 ? 'Unranked • New Member' : 'Lvl $level • ${donorTitle ?? tier}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF24191A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

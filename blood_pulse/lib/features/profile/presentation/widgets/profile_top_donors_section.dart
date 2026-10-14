// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/providers/profile_provider.dart';

/// Stitch Screen 1: Top Donors leaderboard horizontal 5-column layout
/// - Top 4 active verified donors (rank badges #1, #2, #3, #4)
/// - 5th column: "+N View all Others" linking to Global Rank
/// - Header: "Top Donors" with tappable "Global Rank →"
/// 100% dynamic, real database data, privacy-compliant.
class ProfileTopDonorsSection extends ConsumerWidget {
  const ProfileTopDonorsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topDonorsAsync = ref.watch(topDonorsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          // ── Header Row ──
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
              GestureDetector(
                onTap: () => context.push('/global-rank'),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Global Rank',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC30121),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFC30121)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 5-Column Content ──
          topDonorsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(width: 24, height: 24, child: AppLoader()),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Text(
                'Could not load top donors at this moment.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            data: (response) {
              final donors = response.topDonors;
              if (donors.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  alignment: Alignment.center,
                  child: Text(
                    'Be the first verified donor in Bangladesh to claim the #1 spot!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              // Take top 4 donors
              final top4 = donors.take(4).toList();
              final int othersCount = response.otherDonorsCount;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...top4.map((donor) => _buildDonorColumn(context, donor)),
                  _buildOthersColumn(context, othersCount),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDonorColumn(BuildContext context, dynamic donor) {
    final int rank = donor.rank;
    final String name = donor.name;
    final int bags = donor.bags;
    final String? photoUrl = donor.photo;

    final Color badgeColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFFC30121);

    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';

    return GestureDetector(
      onTap: () => context.push('/profile/${donor.id}'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFFFF0F1),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          initial,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: rank == 1 ? const Color(0xFFB45309) : badgeColor,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF24191A),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '$bags ${bags == 1 ? "Bag" : "Bags"}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                color: Color(0xFF5F5E5E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOthersColumn(BuildContext context, int othersCount) {
    final String label = othersCount > 0 ? '+$othersCount' : 'More';

    return GestureDetector(
      onTap: () => context.push('/global-rank'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3F3),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2D6D6)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC30121),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Others',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF24191A),
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'View All',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFC30121),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

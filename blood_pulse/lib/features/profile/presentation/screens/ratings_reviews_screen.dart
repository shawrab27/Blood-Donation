// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../domain/models/donor_review_model.dart';
import '../../domain/providers/profile_provider.dart';
import '../widgets/modals/submit_review_modal.dart';

/// Stitch Screen: Ratings & Reviews Screen
/// Shows donor rating average, distribution bars, and reviews list.
class RatingsReviewsScreen extends ConsumerWidget {
  final int? donorId;
  final String? donorName;
  final int? bloodRequestId;

  const RatingsReviewsScreen({
    super.key,
    this.donorId,
    this.donorName,
    this.bloodRequestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final currentProfile = profileAsync.valueOrNull;

    final targetId = donorId ?? currentProfile?.id ?? 0;
    final reviewsAsync = ref.watch(donorReviewsProvider(targetId));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF24191A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Ratings & Reviews',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF24191A),
          ),
        ),
      ),
      floatingActionButton: bloodRequestId != null && targetId != currentProfile?.id
          ? FloatingActionButton.extended(
              onPressed: () {
                SubmitReviewModal.show(
                  context: context,
                  donorId: targetId,
                  bloodRequestId: bloodRequestId!,
                  donorName: donorName ?? 'Donor',
                );
              },
              backgroundColor: const Color(0xFFC30121),
              icon: const Icon(Icons.rate_review_rounded, color: Colors.white),
              label: const Text(
                'Write Review',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : null,
      body: ResponsiveCenterWrapper(
        maxWidth: 540,
        child: reviewsAsync.when(
          loading: () => const Center(
            child: SizedBox(width: 28, height: 28, child: AppLoader()),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFC30121)),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load reviews.',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(donorReviewsProvider(targetId)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC30121),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // ── Summary Card ──
              _buildSummaryCard(data),
              const SizedBox(height: 20),

              // ── Section Title ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Donor Feedback',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  Text(
                    '${data.reviews.length} total',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Reviews List ──
              if (data.reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0E5E5)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.star_outline_rounded, size: 44, color: Color(0xFFE2D6D6)),
                      SizedBox(height: 8),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF24191A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Feedback from patients and hospitals will appear here after verified donations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _buildReviewCard(data.reviews[i]),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(DonorReviewsResponse data) {
    final counts = [0, 0, 0, 0, 0];
    for (final r in data.reviews) {
      if (r.stars >= 1 && r.stars <= 5) {
        counts[r.stars - 1]++;
      }
    }
    final total = data.reviews.isNotEmpty ? data.reviews.length : 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Average & Stars
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.ratingAvg > 0 ? data.ratingAvg.toStringAsFixed(1) : '5.0',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC30121),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFC30121),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.ratingCount} reviews',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5F5E5E)),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Right side: 5-to-1 Distribution bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final starNum = 5 - i;
                final count = counts[starNum - 1];
                final fraction = count / total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$starNum',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F5E5E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 11, color: Color(0xFF8C8A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF3E5E5),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFC30121)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: Color(0xFF8C8A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(DonorReviewItem review) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.reviewerName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              Text(
                review.timeAgo,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF8C8A8A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 15,
                    color: index < review.stars ? const Color(0xFFC30121) : const Color(0xFFE2D6D6),
                  );
                }),
              ),
              if (review.tag.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    review.tag,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC30121),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: Color(0xFF24191A),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

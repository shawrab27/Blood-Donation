// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../feed/presentation/providers/feed_provider.dart';

/// Card 3 for Blood Hub Landing: Blood Campaigns with Feed navigation.
class LandingCampaignCard extends ConsumerWidget {
  const LandingCampaignCard({
    super.key,
    required this.isBangla,
    required this.onViewAllTap,
  });

  final bool isBangla;
  final VoidCallback onViewAllTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignPosts = ref.watch(activeCampaignsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4E6F7), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F1F8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Color(0xFF0D68AA),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBangla ? 'রক্তদান ক্যাম্পেইন' : 'Blood Campaigns',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isBangla
                                ? '${campaignPosts.length}টি ড্রাইভ চলমান'
                                : '${campaignPosts.length} Drives Ongoing',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF0D68AA),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onViewAllTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0D68AA),
                ),
                child: Text(
                  isBangla ? 'সব দেখুন ➔' : 'View All ➔',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (campaignPosts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  isBangla
                      ? 'বর্তমানে কোনো সক্রিয় রক্তদান ক্যাম্পেইন নেই।'
                      : 'No active blood campaigns nearby at this moment.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF8E7D7F),
                  ),
                ),
              ),
            )
          else
            for (final post in campaignPosts.take(2)) ...[
              if (post.campaign != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0EBF2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.campaign!.title,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B2B2B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF4FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${post.campaign!.currentUnits} / ${post.campaign!.targetUnits} bags',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D68AA),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '📍 ${post.campaign!.venue}  •  🗓️ ${post.campaign!.startDate}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (post.campaign!.currentUnits /
                                  (post.campaign!.targetUnits == 0
                                      ? 1
                                      : post.campaign!.targetUnits))
                              .clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0D68AA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(feedProvider.notifier).pledgeCampaign(post.id);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isBangla
                                      ? 'ধন্যবাদ! আপনি ${post.campaign!.title}-এ রক্তদানের অঙ্গীকার করেছেন।'
                                      : 'Thank you! You pledged to donate at ${post.campaign!.title}.',
                                ),
                                backgroundColor: const Color(0xFF0D68AA),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.volunteer_activism_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: Text(
                            isBangla ? 'রক্তদানের অঙ্গীকার 🩸' : 'Pledge 🩸',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D68AA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Stitch Screen 1: Request List section with urgency badges
class ProfileRequestsList extends StatelessWidget {
  const ProfileRequestsList({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = [
      {
        'title': 'Emergency O- Request',
        'subtitle': 'Dhaka Medical College • 2 units',
        'tag': 'URGENT',
        'tagBg': const Color(0xFFFFDAD6),
        'tagColor': const Color(0xFFBA1A1A),
      },
      {
        'title': 'Platelet Donation Response',
        'subtitle': 'Square Hospital • 1 donor matched',
        'tag': 'CONFIRMED',
        'tagBg': const Color(0xFFD1E4FF),
        'tagColor': const Color(0xFF001D35),
      },
      {
        'title': 'General Blood Drive',
        'subtitle': 'Dhanmondi Club • Campaign active',
        'tag': 'CAMPAIGN',
        'tagBg': const Color(0xFFE8F8F0),
        'tagColor': const Color(0xFF1B8A4E),
      },
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
                'Request List',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              InkWell(
                onTap: () => context.push('/journeys'),
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF3DDE0)),
            itemBuilder: (context, index) {
              final req = requests[index];
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE9EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['title'] as String,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF24191A),
                          ),
                        ),
                        Text(
                          req['subtitle'] as String,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: req['tagBg'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      req['tag'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: req['tagColor'] as Color,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

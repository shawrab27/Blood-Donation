// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

class HealthHubArticlesSection extends StatelessWidget {
  const HealthHubArticlesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Wellness Tip Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.healthWellnessTip ?? 'Daily Hydration Tip',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.healthToolHydrationDesc ??
                          'Drinking 500ml of water 30 minutes before donating blood significantly reduces lightheadedness.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.neutral,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          'Latest Health Articles',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 14),

        _buildArticlesList(context),
      ],
    );
  }

  Widget _buildArticlesList(BuildContext context) {
    final articles = [
      {
        'title': 'Iron-Rich Foods to Eat Before Donating',
        'subtitle': 'Boost your hemoglobin levels naturally.',
        'icon': Icons.restaurant_menu,
        'color': const Color(0xFFC30121),
        'route': '/health-hub/donation-guide',
      },
      {
        'title': 'The Science of Blood Types',
        'subtitle': 'Why O-Negative is the universal donor.',
        'icon': Icons.science,
        'color': const Color(0xFF0D68AA),
        'route': '/health-hub/science-of-blood',
      },
      {
        'title': 'Recovery Best Practices',
        'subtitle': 'What to do in the 24 hours post-donation.',
        'icon': Icons.hotel,
        'color': const Color(0xFF1B8A4E),
        'route': '/health-hub/recovery',
      }
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: articles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final article = articles[index];
        return InkWell(
          onTap: () {
            context.push(article['route'] as String);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (article['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(article['icon'] as IconData, color: article['color'] as Color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article['title'] as String,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article['subtitle'] as String,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

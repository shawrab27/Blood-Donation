// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../widgets/common/health_accessory_contextual_card.dart';
import '../widgets/dashboard/health_hub_status_card.dart';
import '../widgets/dashboard/health_hub_tools_grid.dart';
import '../widgets/dashboard/health_hub_articles_section.dart';

class HealthHubDashboardScreen extends StatelessWidget {
  const HealthHubDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ResponsiveCenterWrapper(
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 8),

          // ── Title & Intro ──────────────────────────────────────────────────
          Text(
            l10n?.healthTitle ?? 'Health Hub',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.healthSubtitle ?? 'Your personal health & donation intelligence center.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 20),

          // ── 1. Summary Status Card ─────────────────────────────────────────
          const HealthHubStatusCard(),

          const SizedBox(height: 16),

          // ── 2. Mandatory 2nd Position: Health & Blood Accessories Feature ─
          const HealthAccessoryContextualCard(
            title: 'Health & Blood Accessories Catalog',
            subtitle: 'Verified diagnostic kits, sphygmomanometers, lancets, and voluntary donor restoration gear.',
            customButtonText: 'Browse 7+ Accessories',
          ),

          const SizedBox(height: 20),

          // ── 3. Tools & Analytics Grid (Accessories in 2nd slot) ───────────
          Text(
            l10n?.healthToolsTitle ?? 'Tools & Analytics',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 14),

          const HealthHubToolsGrid(),

          const SizedBox(height: 28),

          // ── 4. Daily Wellness Tip & Articles ──────────────────────────────
          const HealthHubArticlesSection(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

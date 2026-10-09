// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../auth/presentation/providers/locale_provider.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../widgets/landing/landing_hero_section.dart';
import '../widgets/landing/landing_action_cards.dart';
import '../widgets/landing/landing_campaign_card.dart';
import '../widgets/landing/landing_features_grid.dart';

/// BloodHubLandingScreen conforms directly to Stitch design specification.
/// Features 3 distinct action cards: Search for Donor, Emergency Blood, Blood Campaigns.
class BloodHubLandingScreen extends ConsumerWidget {
  const BloodHubLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isBangla = locale.languageCode == 'bn';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: RefreshIndicator(
            color: const Color(0xFFC30121),
            onRefresh: () async {
              ref.invalidate(activeCampaignsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Header
                  LandingHeroSection(isBangla: isBangla),
                  const SizedBox(height: 20),

                  // 2. Action Cards 1 & 2: Search for Donor & Emergency Blood
                  LandingActionCards(
                    isBangla: isBangla,
                    onSearchTap: () => context.push('/blood-hub/search'),
                    onEmergencyTap: () => context.push('/emergency'),
                  ),
                  const SizedBox(height: 20),

                  // 3. Card 3: Blood Campaigns (Feed filter navigation)
                  LandingCampaignCard(
                    isBangla: isBangla,
                    onViewAllTap: () {
                      ref.read(feedFilterProvider.notifier).state = 'campaign';
                      ref.read(shellTabProvider.notifier).state = 0;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 4. Supporting Features Bento Grid
                  LandingFeaturesGrid(isBangla: isBangla),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

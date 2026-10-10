// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../auth/presentation/providers/locale_provider.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../widgets/landing/landing_action_cards.dart';
import '../widgets/landing/landing_campaign_card.dart';

/// BloodHubLandingScreen: Exactly 3 segments matching Stitch design specification:
/// Segment 1: "Search for Donor"
/// Segment 2: "Emergency Blood" (Crimson gradient with interactive Emergency Dispatch popup card)
/// Segment 3: "Blood Campaigns" (Community Drive preview & Feed integration)
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Action Cards: Segment 1 (Search for Donor) & Segment 2 (Emergency Blood)
                  LandingActionCards(
                    isBangla: isBangla,
                    onSearchTap: () => context.push('/blood-hub/search'),
                    onEmergencyTap: () => context.push('/blood-hub/request/direct'),
                  ),
                  const SizedBox(height: 18),

                  // 2. Action Card: Segment 3 (Blood Campaigns)
                  LandingCampaignCard(
                    isBangla: isBangla,
                    onViewAllTap: () {
                      ref.read(feedFilterProvider.notifier).state = 'campaign';
                      ref.read(shellTabProvider.notifier).state = 0;
                    },
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

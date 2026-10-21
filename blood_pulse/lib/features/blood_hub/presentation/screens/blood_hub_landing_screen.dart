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

/// BloodHubLandingScreen:
/// Segment 1: "Search for Donor"
/// Segment 2: "Emergency Blood" (Crimson gradient with interactive Emergency Dispatch popup card)
/// Segment 3: "Active Requisitions & Journeys" (Part 2: My Requests & My Accepted)
/// Segment 4: "Blood Campaigns" (Community Drive preview & Feed integration)
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

                  // 2. Active Requisitions & Journeys (Part 2 Visible Entry Points)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0E5E5)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC30121).withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC30121).withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.track_changes_rounded,
                                color: Color(0xFFC30121),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isBangla ? 'রক্তের আবেদন ও যাত্রা ট্র্যাকিং' : 'Requisitions & Journey Tracking',
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B2B2B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC30121),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.volunteer_activism_rounded, size: 16),
                                label: Text(
                                  isBangla ? 'আমার আবেদনসমূহ' : 'My Requests',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () => context.push('/journeys?tab=requests'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF0D68AA), width: 1.5),
                                  foregroundColor: const Color(0xFF0D68AA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.directions_run_rounded, size: 16),
                                label: Text(
                                  isBangla ? 'গৃহীত রক্তদান' : 'My Accepted',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () => context.push('/journeys?tab=accepted'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Action Card: Blood Campaigns
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

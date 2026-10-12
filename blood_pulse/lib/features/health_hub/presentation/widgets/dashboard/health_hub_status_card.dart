// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../constants/app_config.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../profile/domain/providers/profile_provider.dart';

class HealthHubStatusCard extends ConsumerWidget {
  const HealthHubStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.asData?.value;

    final String statusTitle;
    final String statusDesc;

    if (profile == null) {
      statusTitle = l10n?.healthStatusOptimal ?? 'Donor Health Status: Optimal';
      statusDesc = 'Eligible Now — Ready to save lives';
    } else if (profile.totalBagsDonated == 0 ||
        profile.lastDonationDate == null ||
        profile.lastDonationDate!.isEmpty) {
      statusTitle = 'Donor Health Status: Eligible';
      statusDesc = 'Eligible Now — Ready to donate blood';
    } else {
      final parsed = DateTime.tryParse(profile.lastDonationDate!);
      if (parsed != null) {
        final daysSince = DateTime.now().difference(parsed).inDays;
        final daysRemaining = (AppConfig.donorCooldownDays - daysSince).clamp(0, AppConfig.donorCooldownDays);
        if (daysRemaining <= 0) {
          statusTitle = 'Donor Health Status: Eligible';
          statusDesc = 'Eligible Now — Cooldown completed';
        } else {
          statusTitle = 'Donor Health Status: Active Recovery';
          statusDesc = 'Next donation in ${daysRemaining}d • Standard cooldown';
        }
      } else {
        statusTitle = 'Donor Health Status: Eligible';
        statusDesc = 'Eligible Now — Ready to donate blood';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDesc,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

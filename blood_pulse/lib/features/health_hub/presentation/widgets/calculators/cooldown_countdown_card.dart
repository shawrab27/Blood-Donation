// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../constants/app_config.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../providers/health_calculators_provider.dart';

class CooldownCountdownCard extends StatelessWidget {
  final HealthCalculatorState state;
  final ValueChanged<DateTime> onDateSelected;

  const CooldownCountdownCard({
    super.key,
    required this.state,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final daysRemaining = state.cooldownDaysRemaining;
    final isReady = daysRemaining <= 0;
    final progress = isReady
        ? 1.0
        : (AppConfig.donorCooldownDays - daysRemaining) /
            AppConfig.donorCooldownDays.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Next Eligible Donation', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral)),
                  const SizedBox(height: 4),
                  Text(
                    isReady ? 'Eligible to Donate Today!' : '$daysRemaining Days Remaining',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isReady ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Select Last Donation Date',
                icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.lastDonationDate ?? now,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now,
                  );
                  if (picked != null) {
                    onDateSelected(picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFF0E5E5),
              color: isReady ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.lastDonationDate != null
                    ? (l10n?.lastDonatedDate(state.lastDonationDate!.toLocal().toString().split(' ')[0]) ??
                        'Last Donated: ${state.lastDonationDate!.toLocal().toString().split(' ')[0]}')
                    : (l10n?.noDonationRecorded ?? 'Last Donated: None recorded'),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral),
              ),
              Text(
                l10n?.standardCooldownDays(AppConfig.donorCooldownDays) ??
                    'Standard ${AppConfig.donorCooldownDays} Days Cooldown',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


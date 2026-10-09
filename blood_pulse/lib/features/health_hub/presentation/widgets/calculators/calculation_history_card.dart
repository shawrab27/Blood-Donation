// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/health_log_entity.dart';

class CalculationHistoryCard extends StatelessWidget {
  final List<HealthLogEntity> historyLogs;

  const CalculationHistoryCard({
    super.key,
    required this.historyLogs,
  });

  @override
  Widget build(BuildContext context) {
    if (historyLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 36, color: Color(0xFFBDBDBD)),
              SizedBox(height: 8),
              Text(
                'No recorded health logs yet',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF555555)),
              ),
              SizedBox(height: 4),
              Text(
                'Save your current vitals above to track your historical trends.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: historyLogs.map((log) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monitor_heart_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BMI: ${log.bmiValue.toStringAsFixed(1)} • BP: ${log.systolicBp}/${log.diastolicBp}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hb: ${log.hemoglobinLevel} g/dL • Pulse: ${log.pulseRateBpm} bpm',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.neutral),
                    ),
                  ],
                ),
              ),
              Text(
                log.timestamp.toLocal().toString().split(' ')[0],
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF888888)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

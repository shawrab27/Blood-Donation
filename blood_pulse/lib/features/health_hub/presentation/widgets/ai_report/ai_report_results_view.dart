// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/health_hub_models.dart';

class AiReportResultsView extends StatelessWidget {
  final AiReportResult result;

  const AiReportResultsView({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Health Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Health Summary',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.summary,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.secondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Extracted Laboratory Parameters',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        ...result.results.map((param) => _buildParameterCard(param)),

        if (result.dietaryActionPlan.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Dietary Action Plan',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          ...result.dietaryActionPlan.map((item) => _buildDietaryPill(item)),
        ],
      ],
    );
  }

  Widget _buildParameterCard(TestResultItem item) {
    final isNormal = item.status.toLowerCase() == 'normal';
    final isLow = item.status.toLowerCase() == 'low';
    final statusColor = isNormal ? AppColors.success : (isLow ? const Color(0xFFD68800) : AppColors.error);
    final statusBg = isNormal ? const Color(0xFFE8F8F0) : (isLow ? const Color(0xFFFFF4E0) : const Color(0xFFFFF0F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.testName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                item.value,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.unit,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Range: ${item.referenceRange}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPill(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.restaurant_menu, size: 15, color: AppColors.tertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.secondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';

/// Contextual Health & Blood Accessories Card
/// Enforces the mandatory BloodPulse rule: Health & Blood Accessories in 2nd position.
class HealthAccessoryContextualCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final String? customButtonText;

  const HealthAccessoryContextualCard({
    super.key,
    this.title = 'Recommended: Health & Blood Accessories',
    this.subtitle = 'Medical-grade monitors, sterile test strips, iron supplements & voluntary donor gear.',
    this.icon = Icons.medical_services_outlined,
    this.accentColor = const Color(0xFFC30121),
    this.bgColor = const Color(0xFFFFF0F1),
    this.customButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ESSENTIAL ACCESSORIES',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/health-hub/accessories');
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(customButtonText ?? 'Explore Health Accessories'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

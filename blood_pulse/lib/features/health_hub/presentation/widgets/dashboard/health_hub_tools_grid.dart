// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

class HealthHubToolsGrid extends StatelessWidget {
  const HealthHubToolsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Mandatory rule: Health & Blood Accessories in 2nd position!
    final List<_FeatureItem> features = [
      _FeatureItem(
        title: l10n?.healthToolScanner ?? 'AI Report Analysis',
        icon: Icons.document_scanner_outlined,
        color: AppColors.primary,
        bgColor: const Color(0xFFFFF0F1),
        route: '/health-hub/ai-report',
      ),
      const _FeatureItem(
        title: 'Health & Blood Accessories',
        icon: Icons.medical_services_outlined,
        color: Color(0xFFC30121),
        bgColor: Color(0xFFFFF0F1),
        route: '/health-hub/accessories',
      ),
      const _FeatureItem(
        title: 'The Science of Blood',
        icon: Icons.science_outlined,
        color: Color(0xFFE65100),
        bgColor: Color(0xFFFFF3E0),
        route: '/health-hub/science-of-blood',
      ),
      _FeatureItem(
        title: l10n?.healthToolCompatibility ?? 'Blood Compatibility',
        icon: Icons.grid_on_rounded,
        color: AppColors.primary,
        bgColor: const Color(0xFFFFF0F1),
        route: '/health-hub/compatibility',
      ),
      const _FeatureItem(
        title: 'Donation Guide',
        icon: Icons.menu_book_outlined,
        color: Color(0xFF1B8A4E),
        bgColor: Color(0xFFE8F5E9),
        route: '/health-hub/donation-guide',
      ),
      _FeatureItem(
        title: l10n?.healthToolResources ?? 'Resources Hub',
        icon: Icons.local_hospital_outlined,
        color: AppColors.tertiary,
        bgColor: const Color(0xFFEDF4FF),
        route: '/health-hub/resources',
      ),
      _FeatureItem(
        title: l10n?.healthToolRecovery ?? 'Recovery & Aftercare',
        icon: Icons.timelapse_outlined,
        color: const Color(0xFF6A1B9A),
        bgColor: const Color(0xFFF3E5F5),
        route: '/health-hub/recovery',
      ),
      _FeatureItem(
        title: l10n?.healthToolReadiness ?? 'Health Calculators',
        icon: Icons.calculate_outlined,
        color: AppColors.tertiary,
        bgColor: const Color(0xFFEDF4FF),
        route: '/health-hub/calculators',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 14) / 2;
        const minHeight = 110.0;
        final safeRatio = (cardWidth / minHeight) < 1.3 ? cardWidth / minHeight : 1.3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: safeRatio,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final item = features[index];
            return InkWell(
              onTap: () => context.push(item.route),
              borderRadius: BorderRadius.circular(20),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: item.bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, color: item.color, size: 21),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FeatureItem {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String route;

  const _FeatureItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.route,
  });
}

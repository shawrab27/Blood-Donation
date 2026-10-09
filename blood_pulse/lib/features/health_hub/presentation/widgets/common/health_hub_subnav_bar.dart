// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';

class HealthHubSubnavBar extends StatelessWidget {
  final String activeRoute;

  const HealthHubSubnavBar({
    super.key,
    required this.activeRoute,
  });

  static const List<_SubnavItem> _navItems = [
    _SubnavItem(label: 'AI Analysis', route: '/health-hub/ai-report', icon: Icons.document_scanner_outlined),
    _SubnavItem(label: 'Accessories', route: '/health-hub/accessories', icon: Icons.medical_services_outlined), // 2nd position!
    _SubnavItem(label: 'Calculators', route: '/health-hub/calculators', icon: Icons.calculate_outlined),
    _SubnavItem(label: 'Science', route: '/health-hub/science-of-blood', icon: Icons.science_outlined),
    _SubnavItem(label: 'Compatibility', route: '/health-hub/compatibility', icon: Icons.grid_on_rounded),
    _SubnavItem(label: 'Guide', route: '/health-hub/donation-guide', icon: Icons.menu_book_outlined),
    _SubnavItem(label: 'Resources', route: '/health-hub/resources', icon: Icons.local_hospital_outlined),
    _SubnavItem(label: 'Recovery', route: '/health-hub/recovery', icon: Icons.timelapse_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _navItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _navItems[index];
          final isActive = item.route == activeRoute;
          return InkWell(
            onTap: () {
              if (!isActive) {
                context.push(item.route);
              }
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isActive ? AppColors.primary : const Color(0xFFE2D6D6),
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 15,
                    color: isActive ? Colors.white : AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubnavItem {
  final String label;
  final String route;
  final IconData icon;

  const _SubnavItem({
    required this.label,
    required this.route,
    required this.icon,
  });
}

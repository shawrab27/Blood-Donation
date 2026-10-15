// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tools & Insights Grid for Health Hub matching Stitch Screen 8b78385103a7437189984b21b2fd2ce3:
/// 1. AI Analysis
/// 2. Health & Blood Accessories
/// 3. Blood Science
/// 4. Compatibility
/// 5. Donation Guide
/// 6. Resources
/// 7. Recovery & Aftercare
/// 8. Calculators
class HealthHubToolsGrid extends StatelessWidget {
  const HealthHubToolsGrid({super.key});

  static const List<HealthHubToolItem> tools = [
    HealthHubToolItem(
      title: 'AI Analysis',
      icon: Icons.analytics_outlined,
      route: '/health-hub/ai-report',
    ),
    HealthHubToolItem(
      title: 'Health & Blood Accessories',
      icon: Icons.medication_outlined,
      route: '/health-hub/accessories',
    ),
    HealthHubToolItem(
      title: 'Blood Science',
      icon: Icons.science_outlined,
      route: '/health-hub/science-of-blood',
    ),
    HealthHubToolItem(
      title: 'Compatibility',
      icon: Icons.diversity_3_outlined,
      route: '/health-hub/compatibility',
    ),
    HealthHubToolItem(
      title: 'Donation Guide',
      icon: Icons.menu_book_outlined,
      route: '/health-hub/donation-guide',
    ),
    HealthHubToolItem(
      title: 'Resources',
      icon: Icons.library_books_outlined,
      route: '/health-hub/resources',
    ),
    HealthHubToolItem(
      title: 'Recovery & Aftercare',
      icon: Icons.healing_outlined,
      route: '/health-hub/recovery',
    ),
    HealthHubToolItem(
      title: 'Calculators',
      icon: Icons.calculate_outlined,
      route: '/health-hub/calculators',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final crossAxisCount = isDesktop ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 176,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _HealthHubToolCard(tool: tool);
          },
        );
      },
    );
  }
}

class HealthHubToolItem {
  final String title;
  final IconData icon;
  final String route;

  const HealthHubToolItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}

class _HealthHubToolCard extends StatefulWidget {
  final HealthHubToolItem tool;

  const _HealthHubToolCard({required this.tool});

  @override
  State<_HealthHubToolCard> createState() => _HealthHubToolCardState();
}

class _HealthHubToolCardState extends State<_HealthHubToolCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        context.push(widget.tool.route);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C8E7D7F),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFF3DDE0).withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE9EB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    widget.tool.icon,
                    color: const Color(0xFFC30121),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.tool.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF24191A),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

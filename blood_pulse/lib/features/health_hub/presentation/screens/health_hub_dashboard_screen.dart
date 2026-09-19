import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class HealthHubDashboardScreen extends StatelessWidget {
  const HealthHubDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
          const SizedBox(height: 8),

          // ── Title & Intro ──────────────────────────────────────────────────
          Text(
            l10n?.healthTitle ?? 'Health Hub',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n?.healthSubtitle ?? 'Your personal health & donation intelligence center.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 20),

          // ── Summary Status Card ───────────────────────────────────────────
          _buildHealthStatusCard(l10n),

          const SizedBox(height: 24),

          // ── 7 Tools & Analytics Grid Title ───────────────────────────────
          Text(
            l10n?.healthToolsTitle ?? 'Tools & Analytics',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 14),

          // ── 7 Tools Grid Cards ────────────────────────────────────────────
          _buildFeatureGrid(context, l10n),

          const SizedBox(height: 28),

          // ── Daily Wellness Tip Card ───────────────────────────────────────
          _buildWellnessTipCard(l10n),

          const SizedBox(height: 40),
        ],
      );
  }

  Widget _buildHealthStatusCard(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(40),
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
                  l10n?.healthStatusOptimal ?? 'Donor Health Status: Optimal',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.healthStatusDesc ?? 'Hemoglobin: 14.2 g/dL • Next donation in 42 days',
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

  Widget _buildFeatureGrid(BuildContext context, AppLocalizations? l10n) {
    final List<_FeatureShortcut> features = [
      _FeatureShortcut(
        title: l10n?.healthToolScanner ?? 'AI Report Analysis',
        icon: Icons.document_scanner_outlined,
        color: AppColors.primary,
        bgColor: const Color(0xFFFFF0F1),
        route: '/health-hub/ai-report',
      ),
      _FeatureShortcut(
        title: l10n?.healthToolReadiness ?? 'Health Calculators',
        icon: Icons.calculate_outlined,
        color: AppColors.tertiary,
        bgColor: const Color(0xFFEDF4FF),
        route: '/health-hub/calculators',
      ),
      _FeatureShortcut(
        title: 'Science of Blood',
        icon: Icons.science_outlined,
        color: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF3E0),
        route: '/health-hub/science-of-blood',
      ),
      _FeatureShortcut(
        title: l10n?.healthToolCompatibility ?? 'Blood Compatibility',
        icon: Icons.grid_on_rounded,
        color: AppColors.primary,
        bgColor: const Color(0xFFFFF0F1),
        route: '/health-hub/compatibility',
      ),
      _FeatureShortcut(
        title: 'Donation Guide',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF1B8A4E),
        bgColor: const Color(0xFFE8F5E9),
        route: '/health-hub/donation-guide',
      ),
      _FeatureShortcut(
        title: l10n?.healthToolResources ?? 'Resources Hub',
        icon: Icons.local_hospital_outlined,
        color: AppColors.tertiary,
        bgColor: const Color(0xFFEDF4FF),
        route: '/health-hub/resources',
      ),
      _FeatureShortcut(
        title: l10n?.healthToolRecovery ?? 'Recovery & Aftercare',
        icon: Icons.timelapse_outlined,
        color: const Color(0xFF6A1B9A),
        bgColor: const Color(0xFFF3E5F5),
        route: '/health-hub/recovery',
      ),
      _FeatureShortcut(
        title: 'Blood & Health Accessories',
        icon: Icons.medical_services_outlined,
        color: const Color(0xFF00796B),
        bgColor: const Color(0xFFE0F2F1),
        route: '/health-hub/accessories',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.3,
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
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
  }

  Widget _buildWellnessTipCard(AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.healthWellnessTip ?? 'Daily Hydration Tip',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n?.healthToolHydrationDesc ??
                      'Drinking 500ml of water 30 minutes before donating blood significantly reduces lightheadedness.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.neutral,
                    height: 1.4,
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

class _FeatureShortcut {
  const _FeatureShortcut({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.route,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String route;
}

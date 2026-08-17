import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../widgets/blood_circulation_diagram_widget.dart';

class ScienceOfBloodScreen extends StatelessWidget {
  const ScienceOfBloodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'The Science of Blood',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),

            // Hero Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Science of Blood',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Understanding the vital fluid that carries life, oxygen, and defense to every cell in the human body.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section 1: Blood Components ─────────────────────────────────
            _sectionHeader('Core Blood Components'),
            const SizedBox(height: 12),

            _componentCard(
              title: 'Red Blood Cells (RBCs)',
              sub: 'Erythrocytes • 45% of total volume',
              desc: 'RBCs contain hemoglobin, an iron-rich protein that binds oxygen in the lungs and delivers it throughout the entire body.',
              icon: Icons.water_drop,
              iconColor: AppColors.primary,
            ),
            const SizedBox(height: 12),

            _componentCard(
              title: 'White Blood Cells (WBCs)',
              sub: 'Leukocytes • Immune system defenders',
              desc: 'WBCs defend the body against infections, viruses, and foreign pathogens. They constitute under 1% of blood volume.',
              icon: Icons.shield_outlined,
              iconColor: AppColors.tertiary,
            ),
            const SizedBox(height: 12),

            _componentCard(
              title: 'Platelets (Thrombocytes)',
              sub: 'Clotting agents • Cell fragments',
              desc: 'Platelets adhere to vessel injury sites to form fibrin clots, stopping bleeding and initiating tissue repair.',
              icon: Icons.grain_rounded,
              iconColor: const Color(0xFFE65100),
            ),
            const SizedBox(height: 12),

            _componentCard(
              title: 'Plasma',
              sub: '55% of total volume • Liquid medium',
              desc: 'A pale yellow liquid comprised of 92% water, proteins, electrolytes, and antibodies that carry cells in suspension.',
              icon: Icons.opacity_outlined,
              iconColor: const Color(0xFFF57C00),
            ),
            const SizedBox(height: 28),

            // ── Section 2: Hemoglobin ────────────────────────────────────────
            _sectionHeader('Hemoglobin & Iron Mechanics'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What is Hemoglobin?',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hemoglobin is the specialized protein molecule in red blood cells that carries oxygen from the lungs to the body\'s tissues and returns carbon dioxide from the tissues back to the lungs.\n\nWHO Minimum Thresholds for Donation:\n• Male: ≥ 13.0 g/dL\n• Female: ≥ 12.5 g/dL',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Section 3: Blood Circulation ─────────────────────────────────
            _sectionHeader('Blood Circulation & Clotting'),
            const SizedBox(height: 12),
            const BloodCirculationDiagramWidget(),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF4FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD0E4FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The Circulatory Loop',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Oxygenated blood leaves the left heart via the aorta.\n2. Arteries branch into micro-capillaries supplying tissues.\n3. Deoxygenated blood returns via veins to the right heart.\n4. The pulmonary cycle re-oxygenates blood in the lungs.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }

  Widget _componentCard({
    required String title,
    required String sub,
    required String desc,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text(sub, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: iconColor)),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

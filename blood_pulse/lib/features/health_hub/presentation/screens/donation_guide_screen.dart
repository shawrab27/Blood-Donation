import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';

class DonationGuideScreen extends StatelessWidget {
  const DonationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Your Guide to Giving Life',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Guide to Giving Life',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Everything you need to know before, during, and after donating blood to ensure a safe and comfortable experience.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section 1: Eligibility Basics ──────────────────────────────
            _sectionHeader('Eligibility Basics'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  _RequirementItem(icon: Icons.cake_outlined, title: 'Age Limit', value: '18 – 65 Years'),
                  Divider(),
                  _RequirementItem(icon: Icons.monitor_weight_outlined, title: 'Minimum Weight', value: '≥ 50 kg (110 lbs)'),
                  Divider(),
                  _RequirementItem(icon: Icons.bloodtype_outlined, title: 'Hemoglobin Level', value: '≥ 13.0 g/dL (Male) | ≥ 12.5 g/dL (Female)'),
                  Divider(),
                  _RequirementItem(icon: Icons.history_outlined, title: 'Donation Interval', value: 'Minimum 120 Days Cooldown'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Section 2: Step-by-Step Donation Journey ───────────────────
            _sectionHeader('The 4-Step Donation Journey'),
            const SizedBox(height: 12),

            _journeyStep(
              stepNumber: '1',
              title: 'Registration',
              description: 'Fill out your donor profile, verify NID, and complete medical history consent.',
            ),
            const SizedBox(height: 12),

            _journeyStep(
              stepNumber: '2',
              title: 'Health Screening',
              description: 'A medical practitioner checks your hemoglobin, blood pressure, temperature, and pulse.',
            ),
            const SizedBox(height: 12),

            _journeyStep(
              stepNumber: '3',
              title: 'The Donation',
              description: 'You relax comfortably in a reclining chair while 1 unit (approx 450ml) is collected in 8–10 mins.',
            ),
            const SizedBox(height: 12),

            _journeyStep(
              stepNumber: '4',
              title: 'Refreshment & Rest',
              description: 'Rest for 15 minutes while enjoying fruit juice and light snacks before resuming normal activities.',
            ),
            const SizedBox(height: 28),

            // ── Section 3: Pre-Donation Tips ─────────────────────────────────
            _sectionHeader('Pre-Donation Checklist'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.water_drop_rounded, color: AppColors.tertiary),
                    title: Text('Hydrate Well', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text('Drink extra 500ml of water or fruit juice 2-3 hours before donating.'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.restaurant_rounded, color: AppColors.success),
                    title: Text('Eat a Healthy Meal', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text('Eat iron-rich foods and avoid fatty meals right before donation.'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.bedtime_rounded, color: AppColors.primary),
                    title: Text('Get Good Sleep', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text('Get at least 7-8 hours of restful sleep the night before.'),
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

  Widget _journeyStep({required String stepNumber, required String title, required String description}) {
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
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }
}

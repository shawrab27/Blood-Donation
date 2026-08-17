import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';

class RecoveryAftercareScreen extends StatefulWidget {
  const RecoveryAftercareScreen({super.key});

  @override
  State<RecoveryAftercareScreen> createState() => _RecoveryAftercareScreenState();
}

class _RecoveryAftercareScreenState extends State<RecoveryAftercareScreen> {
  int _waterGlasses = 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Recovery & Aftercare',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),

            const Text(
              'Post-Donation Recovery Tracker',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Track your body\'s plasma restoration and iron recovery timeline after donating.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 20),

            // ── 24-Hour Progress Dial Card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: 0.80, // 80% recovered
                          strokeWidth: 10,
                          backgroundColor: Colors.grey.shade200,
                          color: AppColors.primary,
                        ),
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('80%', style: TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text('Recovered', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'You are doing great!',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'It has been 24 hours since your donation. Plasma volume is 95% restored.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Hydration Progress Tracker ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF4FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD0E4FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.water_drop_rounded, color: AppColors.tertiary, size: 24),
                      SizedBox(width: 10),
                      Text('Hydration Tracker Today', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_waterGlasses / 8 Glasses Water', style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.tertiary),
                            onPressed: () => setState(() => _waterGlasses = (_waterGlasses - 1).clamp(0, 15)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.tertiary),
                            onPressed: () => setState(() => _waterGlasses = (_waterGlasses + 1).clamp(0, 15)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Recovery Timeline Milestones ────────────────────────────────
            _sectionHeader('Recovery Timeline'),
            const SizedBox(height: 12),

            _timelineTile('0–2 Hours', 'Rest & Immediate Fluids', 'Keep bandage on, drink 500ml water or juice, avoid standing quickly.', true),
            _timelineTile('24 Hours', 'Plasma Volume Restoration', 'Body replaces lost fluid volume. Avoid heavy weightlifting or intense workouts.', true),
            _timelineTile('48 Hours', 'Hydration Complete', 'Fluid levels fully restored. Normal routine & exercise can be resumed.', false),
            _timelineTile('2–3 Weeks', 'Iron & RBC Regeneration', 'Bone marrow actively produces new red blood cells to replace donated units.', false),

            const SizedBox(height: 28),

            // ── Nutrition & Diet Guide ──────────────────────────────────────
            _sectionHeader('Post-Donation Diet Guide'),
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
                    leading: Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
                    title: Text('Iron-Rich Foods', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text('Spinach, red meat, lentils, beans, and dark poultry to boost iron levels.'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.eco_rounded, color: AppColors.warning),
                    title: Text('Vitamin C Boosters', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    subtitle: Text('Oranges, lemons, and guavas enhance intestinal iron absorption.'),
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

  Widget _timelineTile(String time, String title, String desc, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCompleted ? const Color(0xFFA5D6A7) : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? AppColors.success : AppColors.neutral,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    Text(time, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: isCompleted ? AppColors.success : AppColors.neutral)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

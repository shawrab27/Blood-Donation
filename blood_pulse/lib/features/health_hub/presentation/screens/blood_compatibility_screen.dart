import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';

class BloodCompatibilityScreen extends StatefulWidget {
  const BloodCompatibilityScreen({super.key});

  @override
  State<BloodCompatibilityScreen> createState() => _BloodCompatibilityScreenState();
}

class _BloodCompatibilityScreenState extends State<BloodCompatibilityScreen> {
  String _selectedGroup = 'O+';

  static const Map<String, List<String>> _canDonateToMap = {
    'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'], // Universal donor
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A-', 'A+', 'AB-', 'AB+'],
    'A+': ['A+', 'AB+'],
    'B-': ['B-', 'B+', 'AB-', 'AB+'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB-', 'AB+'],
    'AB+': ['AB+'],
  };

  static const Map<String, List<String>> _canReceiveFromMap = {
    'O-': ['O-'],
    'O+': ['O-', 'O+'],
    'A-': ['O-', 'A-'],
    'A+': ['O-', 'O+', 'A-', 'A+'],
    'B-': ['O-', 'B-'],
    'B+': ['O-', 'O+', 'B-', 'B+'],
    'AB-': ['O-', 'A-', 'B-', 'AB-'],
    'AB+': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'], // Universal recipient
  };

  @override
  Widget build(BuildContext context) {
    final canDonate = _canDonateToMap[_selectedGroup] ?? [];
    final canReceive = _canReceiveFromMap[_selectedGroup] ?? [];

    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Blood Compatibility',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),

            const Text(
              'Blood Compatibility Matrix',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a blood group to inspect compatible donors and recipients.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 20),

            // ── Select Blood Group Selector ──────────────────────────────────
            const Text(
              'Select Your Blood Group:',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _canDonateToMap.keys.map((group) {
                final isSelected = group == _selectedGroup;
                return ChoiceChip(
                  label: Text(group, style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppColors.primary)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFFFFF0F1),
                  side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE6BDBA)),
                  onSelected: (val) {
                    if (val) setState(() => _selectedGroup = group);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Results: Can Donate To Card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE6BDBA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_upward_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text('$_selectedGroup Can DONATE Blood To:', style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: canDonate
                        .map((g) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(50)),
                              child: Text(g, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Results: Can Receive From Card ──────────────────────────────
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
                  Row(
                    children: [
                      const Icon(Icons.arrow_downward_rounded, color: AppColors.tertiary, size: 24),
                      const SizedBox(width: 8),
                      Text('$_selectedGroup Can RECEIVE Blood From:', style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: canReceive
                        .map((g) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.tertiary, borderRadius: BorderRadius.circular(50)),
                              child: Text(g, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Universal Stats ─────────────────────────────────────────────
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
                    leading: Icon(Icons.star_rounded, color: AppColors.primary, size: 28),
                    title: Text('Universal Donor: O-Negative', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
                    subtitle: Text('O- negative red blood cells can be safely given to any patient regardless of blood type.'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.stars_rounded, color: AppColors.tertiary, size: 28),
                    title: Text('Universal Recipient: AB-Positive', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
                    subtitle: Text('AB+ patients can receive red blood cells from any blood group.'),
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
}

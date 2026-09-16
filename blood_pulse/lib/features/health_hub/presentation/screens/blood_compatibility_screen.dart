import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../domain/providers/health_hub_provider.dart';

class BloodCompatibilityScreen extends ConsumerStatefulWidget {
  const BloodCompatibilityScreen({super.key});

  @override
  ConsumerState<BloodCompatibilityScreen> createState() => _BloodCompatibilityScreenState();
}

class _BloodCompatibilityScreenState extends ConsumerState<BloodCompatibilityScreen> {
  String _selectedGroup = 'O+';

  @override
  Widget build(BuildContext context) {
    final rulesAsyncValue = ref.watch(compatibilityRulesProvider);

    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Blood Compatibility',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: rulesAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (rules) {
            // If no rules, show empty state
            if (rules.isEmpty) {
              return const Center(child: Text('No compatibility rules available.'));
            }

            // Extract all unique blood groups
            final uniqueGroups = rules.map((e) => e.bloodGroup).toSet().toList()..sort();
            
            // Ensure selected group is valid
            if (!uniqueGroups.contains(_selectedGroup) && uniqueGroups.isNotEmpty) {
              _selectedGroup = uniqueGroups.first;
            }

            // Find the rule for the selected group
            final currentRule = rules.firstWhere(
              (r) => r.bloodGroup == _selectedGroup, 
              orElse: () => rules.first
            );

            // Parse CSV strings from API
            final canDonate = currentRule.canGiveTo.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            final canReceive = currentRule.canReceiveFrom.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

            return ListView(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Blood Compatibility Matrix',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 4),
                const Text(
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
                  children: uniqueGroups.map((group) {
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
                const SizedBox(height: 16),

                // ── Results: Can Receive From Card ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFBBE5D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 24),
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
                                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(50)),
                                  child: Text(g, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

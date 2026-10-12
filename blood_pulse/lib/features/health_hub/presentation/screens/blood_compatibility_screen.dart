import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';

import '../widgets/common/health_hub_subnav_bar.dart';
import '../../domain/providers/health_hub_provider.dart';

class BloodCompatibilityScreen extends ConsumerStatefulWidget {
  const BloodCompatibilityScreen({super.key});

  @override
  ConsumerState<BloodCompatibilityScreen> createState() => _BloodCompatibilityScreenState();
}

class _BloodCompatibilityScreenState extends ConsumerState<BloodCompatibilityScreen> {
  String _selectedGroup = 'O+';

  static const List<String> _fallbackGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  static const Map<String, List<String>> _fallbackDonate = {
    'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A-', 'A+', 'AB-', 'AB+'],
    'A+': ['A+', 'AB+'],
    'B-': ['B-', 'B+', 'AB-', 'AB+'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB-', 'AB+'],
    'AB+': ['AB+'],
  };

  static const Map<String, List<String>> _fallbackReceive = {
    'O-': ['O-'],
    'O+': ['O+', 'O-'],
    'A-': ['A-', 'O-'],
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  };

  @override
  Widget build(BuildContext context) {
    final rulesAsyncValue = ref.watch(compatibilityRulesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'Blood Compatibility',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: rulesAsyncValue.when(
            loading: () => const Center(child: AppLoader()),
            error: (_, __) => _buildCompatibilityContent(isFallback: true),
            data: (rules) {
              if (rules.isEmpty) return _buildCompatibilityContent(isFallback: true);

              final uniqueGroups = rules.map((e) => e.bloodGroup).toSet().toList()..sort();
              if (!uniqueGroups.contains(_selectedGroup) && uniqueGroups.isNotEmpty) {
                _selectedGroup = uniqueGroups.first;
              }

              final currentRule = rules.firstWhere(
                (r) => r.bloodGroup == _selectedGroup,
                orElse: () => rules.first,
              );

              final canDonate = currentRule.canGiveTo.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final canReceive = currentRule.canReceiveFrom.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

              return _buildCompatibilityContent(
                groups: uniqueGroups,
                canDonate: canDonate,
                canReceive: canReceive,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompatibilityContent({
    bool isFallback = false,
    List<String>? groups,
    List<String>? canDonate,
    List<String>? canReceive,
  }) {
    final availableGroups = groups ?? _fallbackGroups;
    final donateList = canDonate ?? (_fallbackDonate[_selectedGroup] ?? ['AB+']);
    final receiveList = canReceive ?? (_fallbackReceive[_selectedGroup] ?? ['O-']);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Top Subnav
        const HealthHubSubnavBar(activeRoute: '/health-hub/compatibility'),

        // ── 1. Header ────────────────────────────────────────────────
        const Text(
          'Blood Compatibility Matrix',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select a blood group to inspect compatible donors and recipients.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
        ),

        // ── 3. Blood Group Selector ──────────────────────────────────
        const Text(
          'Select Blood Group:',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableGroups.map((group) {
            final isSelected = group == _selectedGroup;
            return ChoiceChip(
              label: Text(
                group,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
              ),
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
        const SizedBox(height: 22),

        // ── 4. Can Donate To Card ────────────────────────────────────
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
                  Expanded(
                    child: Text(
                      '$_selectedGroup Can DONATE Blood To:',
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: donateList
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

        // ── 5. Can Receive From Card ─────────────────────────────────
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
                  Expanded(
                    child: Text(
                      '$_selectedGroup Can RECEIVE Blood From:',
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: receiveList
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

        const SizedBox(height: 36),
      ],
    );
  }
}

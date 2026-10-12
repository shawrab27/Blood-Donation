// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../providers/health_calculators_provider.dart';
import '../widgets/calculators/bmi_calculator_card.dart';
import '../widgets/calculators/vitals_log_card.dart';
import '../widgets/calculators/cooldown_countdown_card.dart';
import '../widgets/calculators/hydration_tracker_card.dart';
import '../widgets/calculators/eligibility_prescreen_card.dart';
import '../widgets/calculators/calculation_history_card.dart';
import '../widgets/common/health_hub_subnav_bar.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

class HealthCalculatorsScreen extends ConsumerStatefulWidget {
  const HealthCalculatorsScreen({super.key});

  @override
  ConsumerState<HealthCalculatorsScreen> createState() => _HealthCalculatorsScreenState();
}

class _HealthCalculatorsScreenState extends ConsumerState<HealthCalculatorsScreen> {
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _sysBpCtrl;
  late TextEditingController _diaBpCtrl;
  late TextEditingController _pulseCtrl;
  late TextEditingController _hbCtrl;
  int _waterGlasses = 4;

  @override
  void initState() {
    super.initState();
    final healthState = ref.read(healthCalculatorsProvider);
    _heightCtrl = TextEditingController(text: '${healthState.heightCm.toInt()}');
    _weightCtrl = TextEditingController(text: '${healthState.weightKg.toInt()}');
    _sysBpCtrl = TextEditingController(text: '${healthState.systolicBp}');
    _diaBpCtrl = TextEditingController(text: '${healthState.diastolicBp}');
    _pulseCtrl = TextEditingController(text: '${healthState.pulseRateBpm}');
    _hbCtrl = TextEditingController(text: '${healthState.hemoglobinLevel}');
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _sysBpCtrl.dispose();
    _diaBpCtrl.dispose();
    _pulseCtrl.dispose();
    _hbCtrl.dispose();
    super.dispose();
  }

  void _onInputsChanged() {
    final h = double.tryParse(_heightCtrl.text) ?? 170.0;
    final w = double.tryParse(_weightCtrl.text) ?? 65.0;
    final sys = int.tryParse(_sysBpCtrl.text) ?? 120;
    final dia = int.tryParse(_diaBpCtrl.text) ?? 80;
    final pulse = int.tryParse(_pulseCtrl.text) ?? 72;
    final hb = double.tryParse(_hbCtrl.text) ?? 14.0;

    ref.read(healthCalculatorsProvider.notifier).updateMetrics(
          heightCm: h,
          weightKg: w,
          systolicBp: sys,
          diastolicBp: dia,
          pulseRateBpm: pulse,
          hemoglobinLevel: hb,
        );
  }

  void _onSaveLog() {
    ref.read(healthCalculatorsProvider.notifier).saveCurrentLog();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💾 Health log saved successfully to persistent history!', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthCalculatorsProvider);

    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Health Calculators',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Top Subnav
            const HealthHubSubnavBar(activeRoute: '/health-hub/calculators'),

            // ── Priority Header Card ─────────────────────────────────────────
            _buildPriorityHeader(healthState),
            const SizedBox(height: 14),


            // ── 1. BMI & Weight Eligibility Calculator ─────────────────────
            _sectionHeader('1. BMI & Weight Eligibility Calculator'),
            const SizedBox(height: 10),
            BmiCalculatorCard(
              state: healthState,
              heightCtrl: _heightCtrl,
              weightCtrl: _weightCtrl,
              onInputsChanged: _onInputsChanged,
            ),
            const SizedBox(height: 22),

            // ── 2. Vital Health & Vitals Engine ────────────────────────────
            _sectionHeader('2. Vital Health & Vitals Engine'),
            const SizedBox(height: 10),
            VitalsLogCard(
              state: healthState,
              sysBpCtrl: _sysBpCtrl,
              diaBpCtrl: _diaBpCtrl,
              pulseCtrl: _pulseCtrl,
              hbCtrl: _hbCtrl,
              onInputsChanged: _onInputsChanged,
            ),
            const SizedBox(height: 22),

            // ── 3. 90-Day Donation Cooldown Bridge ────────────────────────
            if (ref.watch(authProvider).user?.userIntent != 'ONLY_REQUEST') ...[
              _sectionHeader('3. 90-Day Donation Cooldown Engine'),
              const SizedBox(height: 10),
              CooldownCountdownCard(
                state: healthState,
                onDateSelected: (date) {
                  ref.read(healthCalculatorsProvider.notifier).updateMetrics(lastDonationDate: date);
                },
              ),
              const SizedBox(height: 22),
            ],

            // ── 4. Daily Hydration Intake Tracker ──────────────────────────
            _sectionHeader('4. Pre-Donation Hydration Tracker'),
            const SizedBox(height: 10),
            HydrationTrackerCard(
              glasses: _waterGlasses,
              onAddGlass: () => setState(() => _waterGlasses++),
              onRemoveGlass: () => setState(() {
                if (_waterGlasses > 0) _waterGlasses--;
              }),
            ),
            const SizedBox(height: 22),

            // ── 5. Pre-Screening Eligibility Checklist ─────────────────────
            _sectionHeader('5. Pre-Screening Eligibility Checklist'),
            const SizedBox(height: 10),
            const EligibilityPrescreenCard(),
            const SizedBox(height: 24),

            // Save CTA
            CapsuleButton(
              label: 'Save Vitals & Health Log',
              icon: Icons.save_rounded,
              showGlow: true,
              onPressed: _onSaveLog,
            ),
            const SizedBox(height: 28),

            // ── 6. Historical Calculation Logs ─────────────────────────────
            _sectionHeader('6. Historical Trends & Logs'),
            const SizedBox(height: 10),
            CalculationHistoryCard(historyLogs: healthState.historyLogs),

            const SizedBox(height: 40),
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
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }

  Widget _buildPriorityHeader(HealthCalculatorState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health & Readiness Calculator',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BMI: ${state.bmi.toStringAsFixed(1)} • Next donation in ${state.cooldownDaysRemaining} days',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

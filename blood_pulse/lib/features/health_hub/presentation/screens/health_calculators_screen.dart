import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../providers/health_calculators_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final healthState = ref.read(healthCalculatorsProvider);
    _heightCtrl = TextEditingController(text: '${healthState.heightCm.toInt()}');
    _weightCtrl = TextEditingController(text: '${healthState.weightKg.toInt()}');
    _sysBpCtrl  = TextEditingController(text: '${healthState.systolicBp}');
    _diaBpCtrl  = TextEditingController(text: '${healthState.diastolicBp}');
    _pulseCtrl  = TextEditingController(text: '${healthState.pulseRateBpm}');
    _hbCtrl     = TextEditingController(text: '${healthState.hemoglobinLevel}');
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
    final h  = double.tryParse(_heightCtrl.text) ?? 170.0;
    final w  = double.tryParse(_weightCtrl.text) ?? 65.0;
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
            const SizedBox(height: 8),

            // ── Featured Priority Header Card (Smooth Gradient & Heart Icon) ─
            _buildPriorityHeaderCard(healthState),
            const SizedBox(height: 24),

            // ── 1. BMI & Weight Eligibility Calculator ───────────────────────
            _sectionHeader('1. BMI & Weight Eligibility Calculator'),
            const SizedBox(height: 12),
            _buildBmiWeightCard(healthState),
            const SizedBox(height: 24),

            // ── 2. Vital Health & Heart Rate Log Engine ──────────────────────
            _sectionHeader('2. Vital Health & Vitals Engine'),
            const SizedBox(height: 12),
            _buildVitalsLogCard(healthState),
            const SizedBox(height: 24),

            // ── 3. 120-Day Donation Cooldown Bridge ──────────────────────────
            _sectionHeader('3. 120-Day Donation Cooldown Engine'),
            const SizedBox(height: 12),
            _build120DayCooldownCard(healthState),
            const SizedBox(height: 24),

            // Save CTA
            CapsuleButton(
              label: 'Save Vitals & Health Log',
              icon: Icons.save_rounded,
              showGlow: true,
              onPressed: _onSaveLog,
            ),
            const SizedBox(height: 28),

            // ── 4. Historical Health Calculation Logs ────────────────────────
            _sectionHeader('4. Calculation History & Trends'),
            const SizedBox(height: 12),
            _buildHistoryLogsList(healthState),

            const SizedBox(height: 40),
          ],
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

  Widget _buildPriorityHeaderCard(HealthCalculatorState state) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC30121), Color(0xFF8E0017)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(48, 48),
                painter: _MedicalHeartPulsePainter(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Donation Readiness Status',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.overallEligibilityStatus
                          ? '✅ Fully Eligible for Voluntary Blood Donation'
                          : '⚠️ Caution: Check minimum weight & cooldown rules below',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat('Wellness Score', '${state.wellnessScore} / 100'),
              _headerStat('Est. Blood Vol.', '${state.estimatedBloodVolumeLiters.toStringAsFixed(1)} L'),
              _headerStat('Cooldown', state.cooldownDaysRemaining == 0 ? 'Ready!' : '${state.cooldownDaysRemaining} Days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildBmiWeightCard(HealthCalculatorState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _heightCtrl,
                  hint: '172',
                  label: 'Height (cm)',
                  prefixIcon: Icons.height_rounded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onInputsChanged(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomInputField(
                  controller: _weightCtrl,
                  hint: '68',
                  label: 'Weight (kg)',
                  prefixIcon: Icons.monitor_weight_outlined,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onInputsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Minimum Weight Check Banner (≥ 50 kg requirement)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: state.isWeightEligible ? const Color(0xFFE8F5E9) : const Color(0xFFFFECEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: state.isWeightEligible ? AppColors.success : AppColors.error),
            ),
            child: Row(
              children: [
                Icon(
                  state.isWeightEligible ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: state.isWeightEligible ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.isWeightEligible
                        ? 'Weight requirement met: ${state.weightKg.toStringAsFixed(1)} kg (≥ 50 kg minimum)'
                        : 'Weight requirement NOT met: Must be at least 50 kg to donate blood safely.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: state.isWeightEligible ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // BMI Result Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Body Mass Index (BMI)', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
                    Text(state.bmi.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(50)),
                  child: Text(state.bmiCategory, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsLogCard(HealthCalculatorState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _sysBpCtrl,
                  hint: '120',
                  label: 'Systolic BP (mmHg)',
                  prefixIcon: Icons.favorite_outline_rounded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onInputsChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomInputField(
                  controller: _diaBpCtrl,
                  hint: '80',
                  label: 'Diastolic BP (mmHg)',
                  prefixIcon: Icons.favorite_border_rounded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onInputsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _pulseCtrl,
                  hint: '72',
                  label: 'Pulse (BPM)',
                  prefixIcon: Icons.show_chart_rounded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onInputsChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomInputField(
                  controller: _hbCtrl,
                  hint: '14.2',
                  label: 'Hemoglobin (g/dL)',
                  prefixIcon: Icons.opacity_rounded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _onInputsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vitals Status Indicators
          Row(
            children: [
              Expanded(
                child: _vitalBadge('BP Status', '${state.systolicBp}/${state.diastolicBp}', state.isBpEligible),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _vitalBadge('Pulse Status', '${state.pulseRateBpm} BPM', state.isPulseEligible),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _vitalBadge('Hb Level', '${state.hemoglobinLevel} g/dL', state.isHemoglobinEligible),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalBadge(String title, String val, bool isGood) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isGood ? const Color(0xFFE8F5E9) : const Color(0xFFFFECEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.neutral)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: isGood ? AppColors.success : AppColors.error)),
        ],
      ),
    );
  }

  Widget _build120DayCooldownCard(HealthCalculatorState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD0E4FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: AppColors.tertiary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timelapse_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('120-Day Donation Rule', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text(
                  state.cooldownDaysRemaining == 0
                      ? '🎉 Cooldown complete! You are ready to donate blood.'
                      : '⏳ ${state.cooldownDaysRemaining} days remaining until your next eligible donation date.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLogsList(HealthCalculatorState state) {
    if (state.historyLogs.isEmpty) {
      return const Center(
        child: Text('No historical calculation logs recorded yet.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
      );
    }

    return Column(
      children: state.historyLogs.map((log) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: log.overallEligibilityStatus ? const Color(0xFFE8F5E9) : const Color(0xFFFFECEE),
                child: Icon(
                  log.overallEligibilityStatus ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: log.overallEligibilityStatus ? AppColors.success : AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('BMI: ${log.bmiValue.toStringAsFixed(1)} (${log.bmiCategory})', style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        Text('${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weight: ${log.weightKg}kg • BP: ${log.systolicBp}/${log.diastolicBp} • Pulse: ${log.pulseRateBpm} BPM • Score: ${log.wellnessScore}/100',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Custom painter for the modern minimalist medical heart pulse icon.
class _MedicalHeartPulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // ECG pulse line crossing through middle
    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.25, h * 0.5);
    path.lineTo(w * 0.35, h * 0.25);
    path.lineTo(w * 0.5, h * 0.75);
    path.lineTo(w * 0.65, h * 0.35);
    path.lineTo(w * 0.75, h * 0.5);
    path.lineTo(w, h * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

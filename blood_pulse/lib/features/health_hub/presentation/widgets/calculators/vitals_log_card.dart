// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/custom_input_field.dart';
import '../../providers/health_calculators_provider.dart';

class VitalsLogCard extends StatelessWidget {
  final HealthCalculatorState state;
  final TextEditingController sysBpCtrl;
  final TextEditingController diaBpCtrl;
  final TextEditingController pulseCtrl;
  final TextEditingController hbCtrl;
  final VoidCallback onInputsChanged;

  const VitalsLogCard({
    super.key,
    required this.state,
    required this.sysBpCtrl,
    required this.diaBpCtrl,
    required this.pulseCtrl,
    required this.hbCtrl,
    required this.onInputsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isBpNormal = state.systolicBp >= 90 && state.systolicBp <= 140 && state.diastolicBp >= 60 && state.diastolicBp <= 90;
    final isHbNormal = state.hemoglobinLevel >= 12.5;

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
              _buildVitalsChip(
                label: 'BP Status',
                value: '${state.systolicBp}/${state.diastolicBp}',
                isNormal: isBpNormal,
              ),
              const SizedBox(width: 10),
              _buildVitalsChip(
                label: 'Hemoglobin',
                value: '${state.hemoglobinLevel} g/dL',
                isNormal: isHbNormal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  label: 'Systolic BP (mmHg)',
                  hint: '120',
                  controller: sysBpCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onInputsChanged(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomInputField(
                  label: 'Diastolic BP (mmHg)',
                  hint: '80',
                  controller: diaBpCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onInputsChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  label: 'Pulse Rate (bpm)',
                  hint: '72',
                  controller: pulseCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onInputsChanged(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomInputField(
                  label: 'Hemoglobin (g/dL)',
                  hint: '14.0',
                  controller: hbCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onInputsChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsChip({required String label, required String value, required bool isNormal}) {
    final color = isNormal ? AppColors.success : const Color(0xFFD68800);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

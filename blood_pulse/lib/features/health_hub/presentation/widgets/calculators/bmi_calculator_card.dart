// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/custom_input_field.dart';
import '../../providers/health_calculators_provider.dart';

class BmiCalculatorCard extends StatelessWidget {
  final HealthCalculatorState state;
  final TextEditingController heightCtrl;
  final TextEditingController weightCtrl;
  final VoidCallback onInputsChanged;

  const BmiCalculatorCard({
    super.key,
    required this.state,
    required this.heightCtrl,
    required this.weightCtrl,
    required this.onInputsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bmi = state.bmi;
    final category = state.bmiCategory;
    Color categoryColor;
    if (category == 'Normal Weight') {
      categoryColor = AppColors.success;
    } else if (category == 'Underweight' || category == 'Overweight') {
      categoryColor = const Color(0xFFD68800);
    } else {
      categoryColor = AppColors.error;
    }

    final isEligibleWeight = state.weightKg >= 50.0 && state.weightKg <= 600.0;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Body Mass Index (BMI)', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral)),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        category == 'Invalid Input' ? '--' : bmi.toStringAsFixed(1),
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 32, fontWeight: FontWeight.bold, color: categoryColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: categoryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEligibleWeight ? const Color(0xFFE8F8F0) : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEligibleWeight ? Icons.check_circle_rounded : Icons.warning_rounded,
                      color: isEligibleWeight ? AppColors.success : AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEligibleWeight ? 'Weight ≥50kg' : 'Weight <50kg',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isEligibleWeight ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  label: 'Height (cm)',
                  hint: '170',
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onInputsChanged(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomInputField(
                  label: 'Weight (kg)',
                  hint: '65',
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onInputsChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

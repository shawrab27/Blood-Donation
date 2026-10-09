// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class EligibilityPrescreenCard extends StatefulWidget {
  const EligibilityPrescreenCard({super.key});

  @override
  State<EligibilityPrescreenCard> createState() => _EligibilityPrescreenCardState();
}

class _EligibilityPrescreenCardState extends State<EligibilityPrescreenCard> {
  bool _ageValid = true;
  bool _weightValid = true;
  bool _hbValid = true;
  bool _noFever = true;
  bool _noTattoo = true;

  @override
  Widget build(BuildContext context) {
    final allPassed = _ageValid && _weightValid && _hbValid && _noFever && _noTattoo;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pre-Donation Eligibility Check',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allPassed ? const Color(0xFFE8F8F0) : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  allPassed ? 'Eligible' : 'Action Required',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: allPassed ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckRow('Age between 18 and 60 years', _ageValid, (v) => setState(() => _ageValid = v ?? false)),
          _buildCheckRow('Body weight is 50 kg or above', _weightValid, (v) => setState(() => _weightValid = v ?? false)),
          _buildCheckRow('Hemoglobin is 12.5 g/dL or above', _hbValid, (v) => setState(() => _hbValid = v ?? false)),
          _buildCheckRow('Free from fever, cold or antibiotic use in past 7 days', _noFever, (v) => setState(() => _noFever = v ?? false)),
          _buildCheckRow('No tattoos, dental surgery, or piercings in past 6 months', _noTattoo, (v) => setState(() => _noTattoo = v ?? false)),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: onChanged,
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF444444)),
            ),
          ),
        ],
      ),
    );
  }
}

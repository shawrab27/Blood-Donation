// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';

/// Pill-shaped text input field conforming to BloodPulse UI rules.
class PosterInputPill extends StatelessWidget {
  const PosterInputPill({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12.5,
        color: AppColors.secondary,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: Color(0xFF8E7D7F),
        ),
        filled: true,
        fillColor: const Color(0xFFFFF8F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xFFE8DADA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xFFE8DADA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Pill-shaped blood group dropdown selector.
class PosterBloodDropdown extends StatelessWidget {
  const PosterBloodDropdown({
    super.key,
    required this.value,
    required this.isBangla,
    required this.onChanged,
  });

  final String value;
  final bool isBangla;
  final ValueChanged<String> onChanged;

  static const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: isBangla ? 'রক্তের গ্রুপ' : 'Blood Group',
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: Color(0xFF8E7D7F),
        ),
        filled: true,
        fillColor: const Color(0xFFFFF8F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xFFE8DADA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xFFE8DADA)),
        ),
      ),
      items: bloodGroups
          .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
          .toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}

/// Pill-shaped units needed increment/decrement stepper.
class PosterUnitsStepper extends StatelessWidget {
  const PosterUnitsStepper({
    super.key,
    required this.units,
    required this.isBangla,
    required this.onChanged,
  });

  final int units;
  final bool isBangla;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F7),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFE8DADA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              if (units > 1) onChanged(units - 1);
            },
            child: const Icon(Icons.remove_circle_outline,
                size: 20, color: AppColors.primary),
          ),
          Text(
            '$units ${isBangla ? 'ব্যাগ' : 'Bags'}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          InkWell(
            onTap: () => onChanged(units + 1),
            child: const Icon(Icons.add_circle_outline,
                size: 20, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Urgency level pill selector.
class PosterUrgencyChips extends StatelessWidget {
  const PosterUrgencyChips({
    super.key,
    required this.selectedLevel,
    required this.onChanged,
  });

  final String selectedLevel;
  final ValueChanged<String> onChanged;

  static const urgencyLevels = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: urgencyLevels.map((lvl) {
        final isSelected = selectedLevel == lvl;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ChoiceChip(
              label: Text(
                lvl,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.secondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFFF3DDE0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              onSelected: (_) => onChanged(lvl),
            ),
          ),
        );
      }).toList(),
    );
  }
}

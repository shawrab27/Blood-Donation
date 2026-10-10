// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';

/// Modal bottom sheet for BloodPulse mission & rules.
class DrawerLearnMoreSheet extends StatelessWidget {
  const DrawerLearnMoreSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DrawerLearnMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'About BloodPulse',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Mission & Vision',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'BloodPulse is a community-driven blood donation management network designed to eliminate emergency blood shortages. We connect voluntary donors with emergency patients, verified trauma centers, and regional blood banks in minutes.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Eligibility & Health Rules',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Age: 18 to 60 years old\n• Weight: At least 45 kg (or 50 kg for platelets)\n• Hemoglobin: ≥ 12.5 g/dL\n• Donation Interval: 90 days since last donation\n• Healthy with no active fever or antibiotic medications',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.6, color: Color(0xFF555555)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '100% Free & Transparent',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'BloodPulse charges zero fees to patients, donors, or hospitals. Blood donation is a pure act of humanitarian kindness.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5, color: Color(0xFF555555)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

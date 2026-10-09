// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class HydrationTrackerCard extends StatelessWidget {
  final int glasses;
  final VoidCallback onAddGlass;
  final VoidCallback onRemoveGlass;

  const HydrationTrackerCard({
    super.key,
    required this.glasses,
    required this.onAddGlass,
    required this.onRemoveGlass,
  });

  @override
  Widget build(BuildContext context) {
    const targetGlasses = 10;
    final totalMl = glasses * 250;
    final progress = (glasses / targetGlasses).clamp(0.0, 1.0);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: AppColors.tertiary, size: 26),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hydration Tracker',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                      Text(
                        '$totalMl ml / 2,500 ml target',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '$glasses / $targetGlasses glasses',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.tertiary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.tertiary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: glasses > 0 ? onRemoveGlass : null,
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('Remove', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB0CDEE)),
                  foregroundColor: AppColors.tertiary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onAddGlass,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Add 250ml Glass'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tertiary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

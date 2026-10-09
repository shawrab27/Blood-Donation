// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Shimmer-like skeleton cards displayed during loading states.
class DonorSearchSkeleton extends StatelessWidget {
  const DonorSearchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(4, (index) => _skeletonCard()),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: 140, height: 16),
                  const SizedBox(height: 6),
                  _shimmerBox(width: 100, height: 12),
                ],
              ),
              _shimmerBox(width: 38, height: 24, borderRadius: 50),
            ],
          ),
          const SizedBox(height: 14),
          _shimmerBox(width: double.infinity, height: 42, borderRadius: 12),
          const SizedBox(height: 12),
          _shimmerBox(width: double.infinity, height: 40, borderRadius: 50),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3DDE0).withAlpha(120),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

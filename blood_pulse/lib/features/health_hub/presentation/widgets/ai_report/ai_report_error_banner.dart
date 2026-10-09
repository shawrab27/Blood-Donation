// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';

class AiReportErrorBanner extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const AiReportErrorBanner({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Validation Warning',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Please ensure the photo is well-lit and clearly shows laboratory blood parameters (such as CBC, Hemoglobin, Platelets, or Blood Group).',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: Color(0xFF666666),
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                label: const Text('Try Again', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

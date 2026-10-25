// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
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
    final isNotReport = errorMessage.toLowerCase().contains('not a blood report') ||
        errorMessage.toLowerCase().contains('incorrect image') ||
        errorMessage.toLowerCase().contains('unrecognized') ||
        errorMessage.toLowerCase().contains('no text detected') ||
        errorMessage.toLowerCase().contains('invalid');

    final title = isNotReport
        ? "This doesn't look like a blood report"
        : 'Report Analysis Notice';

    final guidanceText = isNotReport
        ? "We couldn't detect blood test markers (such as CBC, Hemoglobin, Platelets, or Blood Group) in this image. Please upload a clear photo of an official diagnostic lab report."
        : errorMessage;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNotReport ? Icons.document_scanner_outlined : Icons.error_outline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guidanceText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: Color(0xFF555555),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFEBEE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFD68800)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Place report flat, avoid glare/shadows, and ensure test names and numerical values are clearly in focus.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: Color(0xFF666666),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Medical disclaimer
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.health_and_safety_outlined, size: 14, color: Color(0xFF888888)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Medical Disclaimer: BloodPulse AI analysis provides informational wellness screening only and does not substitute professional medical diagnosis or consultation with a certified doctor.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF777777),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: PressableScale(child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.primary),
                label: const Text('Select Another Photo', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              )),
            ),
          ],
        ],
      ),
    );
  }
}

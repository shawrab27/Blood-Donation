import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/capsule_button.dart';

class AiReportUploadCard extends StatelessWidget {
  final XFile? reportFile;
  final bool isAnalyzing;
  final VoidCallback onPickImage;
  final VoidCallback onAnalyze;

  const AiReportUploadCard({
    super.key,
    required this.reportFile,
    required this.isAnalyzing,
    required this.onPickImage,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload Card
        GestureDetector(
          onTap: isAnalyzing ? null : onPickImage,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: reportFile != null ? Colors.white : const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: reportFile != null ? AppColors.primary : const Color(0xFFE6BDBA),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: reportFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'Upload Blood Report Photo',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Supports CBC, Hemoglobin & pathology lab reports (JPG, PNG)',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description_outlined, color: AppColors.primary, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        reportFile!.name.isNotEmpty ? reportFile!.name : 'Blood Report Photo Attached',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ready for analysis • Tap to choose a different photo',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 18),

        if (isAnalyzing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: const [
                AppLoader(),
                SizedBox(height: 14),
                Text(
                  'Extracting OCR text & analyzing with Medical AI...',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                ),
              ],
            ),
          )
        else
          CapsuleButton(
            label: 'Analyse with AI',
            icon: Icons.psychology_rounded,
            onPressed: onAnalyze,
          ),
      ],
    );
  }
}

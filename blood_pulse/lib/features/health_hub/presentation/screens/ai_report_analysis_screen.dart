// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../domain/models/health_hub_models.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../widgets/ai_report/ai_report_error_banner.dart';
import '../widgets/ai_report/ai_report_results_view.dart';
import '../widgets/ai_report/ai_report_upload_card.dart';

class AiReportAnalysisScreen extends StatefulWidget {
  const AiReportAnalysisScreen({super.key});

  @override
  State<AiReportAnalysisScreen> createState() => _AiReportAnalysisScreenState();
}

class _AiReportAnalysisScreenState extends State<AiReportAnalysisScreen> {
  final _picker = ImagePicker();
  XFile? _reportFile;
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  AiReportResult? _analysisResult;
  String? _errorMessage;

  Future<void> _pickReport() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked != null && mounted) {
        setState(() {
          _reportFile = picked;
          _hasAnalyzed = false;
          _analysisResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[AiReportAnalysis] Error picking file: $e');
    }
  }

  Future<void> _runAnalysis() async {
    if (_reportFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a report image first.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await AiAnalysisService.analyzeReport(_reportFile!);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _hasAnalyzed = true;
          _analysisResult = result;
        });
      }
    } catch (e) {
      debugPrint('[AiReportAnalysis] Analysis error: $e');
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '').trim();
        final displayError = errText.contains('incorrect image or not a blood report')
            ? 'incorrect image or not a blood report'
            : errText;

        setState(() {
          _isAnalyzing = false;
          _errorMessage = displayError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'AI Report Scanner',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── Section 1: Intro Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF4FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD0E4FF)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.psychology_outlined, color: AppColors.tertiary, size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Blood Report Scanner',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Upload CBC or lab reports for on-device OCR extraction and intelligent clinical dietary recommendations.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Section 3: Document Upload Card & Analyze CTA ───────────────
            AiReportUploadCard(
              reportFile: _reportFile,
              isAnalyzing: _isAnalyzing,
              onPickImage: _pickReport,
              onAnalyze: _runAnalysis,
            ),

            // ── Section 4: Image Validation Error Banner ────────────────────
            if (_errorMessage != null)
              AiReportErrorBanner(
                errorMessage: _errorMessage!,
                onRetry: _pickReport,
              ),

            // ── Section 5: AI Structured Analysis Results ───────────────────
            if (_hasAnalyzed && _analysisResult != null) ...[
              const Divider(height: 44, thickness: 1, color: Color(0xFFEEEEEE)),
              AiReportResultsView(result: _analysisResult!),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

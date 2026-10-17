// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
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
  final _pasteController = TextEditingController();
  XFile? _reportFile;
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  bool _isPasteMode = false;
  AiReportResult? _analysisResult;
  String? _errorMessage;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

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

  Future<void> _runTextAnalysis() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste or type your CBC report text first.', style: TextStyle(fontFamily: 'Inter')),
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
      final result = await AiAnalysisService.analyzeReportText(text);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _hasAnalyzed = true;
          _analysisResult = result;
        });
      }
    } catch (e) {
      debugPrint('[AiReportAnalysis] Text analysis error: $e');
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

            const SizedBox(height: 16),

            // ── Section 2: Input Mode Selector ──────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(50),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPasteMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isPasteMode ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Upload Photo',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: !_isPasteMode ? Colors.white : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPasteMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isPasteMode ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Paste CBC Text',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isPasteMode ? Colors.white : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Section 3: Document Upload Card or Paste Input ──────────────
            if (!_isPasteMode)
              AiReportUploadCard(
                reportFile: _reportFile,
                isAnalyzing: _isAnalyzing,
                onPickImage: _pickReport,
                onAnalyze: _runAnalysis,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _pasteController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Paste complete blood count (CBC) values here...\n\nExample:\nHemoglobin: 11.8 g/dL\nPlatelets: 180,000 /mcL\nWBC: 6,500 /mcL\nRBC: 4.5 million/mcL',
                        hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 14),
                    CapsuleButton(
                      label: _isAnalyzing ? 'Analyzing...' : 'Analyze CBC Report',
                      icon: Icons.analytics_outlined,
                      isLoading: _isAnalyzing,
                      onPressed: _isAnalyzing ? null : _runTextAnalysis,
                    ),
                  ],
                ),
              ),

            // ── Section 4: Image Validation Error Banner ────────────────────
            if (_errorMessage != null)
              AiReportErrorBanner(
                errorMessage: _errorMessage!,
                onRetry: _isPasteMode ? _runTextAnalysis : _pickReport,
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

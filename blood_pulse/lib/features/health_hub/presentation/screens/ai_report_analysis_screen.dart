import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../domain/models/health_hub_models.dart';
import '../../domain/providers/health_hub_provider.dart';

class AiReportAnalysisScreen extends StatefulWidget {
  const AiReportAnalysisScreen({super.key});

  @override
  State<AiReportAnalysisScreen> createState() => _AiReportAnalysisScreenState();
}

class _AiReportAnalysisScreenState extends State<AiReportAnalysisScreen> {
  final _picker = ImagePicker();
  File? _reportFile;
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  AiReportResult? _analysisResult;
  String? _errorMessage;

  Future<void> _pickReport() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() {
          _reportFile = File(picked.path);
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
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'AI Report Analysis',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
            const SizedBox(height: 8),

            // Intro Card
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
                          style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Upload CBC or lab reports for an AI-powered summary and dietary recommendations.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Upload Box
            GestureDetector(
              onTap: _pickReport,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: _reportFile != null ? Colors.white : const Color(0xFFFFF0F1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _reportFile != null ? AppColors.primary : const Color(0xFFE6BDBA), width: 1.5),
                ),
                child: _reportFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
                          SizedBox(height: 8),
                          Text('Upload Your Blood Report', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          SizedBox(height: 4),
                          Text('Supports JPG, PNG lab reports', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                          SizedBox(height: 8),
                          Text('Report File Attached', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success)),
                          SizedBox(height: 4),
                          Text('Tap to replace document', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            if (!_hasAnalyzed && !_isAnalyzing)
              CapsuleButton(
                label: 'Analyze with Gemini AI',
                onPressed: _runAnalysis,
              ),

            if (_isAnalyzing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: const [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'AI is processing your report...',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral),
                    )
                  ],
                ),
              ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error))),
                  ],
                ),
              ),

            if (_hasAnalyzed && _analysisResult != null) ...[
              const Divider(height: 48, thickness: 1, color: Color(0xFFEEEEEE)),
              _buildAnalysisResult(_analysisResult!),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
    );
  }

  Widget _buildAnalysisResult(AiReportResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('AI Health Summary', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.summary,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.secondary, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text('Test Results', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
        const SizedBox(height: 12),
        ...result.results.map((param) => _buildParameterCard(param)),
        
        if (result.dietaryActionPlan.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Dietary Action Plan', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.dietaryActionPlan.map((item) => _buildDietaryPill(item)).toList(),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildParameterCard(TestResultItem item) {
    final isNormal = item.status.toLowerCase() == 'normal';
    final isLow = item.status.toLowerCase() == 'low';
    final statusColor = isNormal ? AppColors.success : (isLow ? const Color(0xFFD68800) : AppColors.error);
    final statusBg = isNormal ? const Color(0xFFE8F8F0) : (isLow ? const Color(0xFFFFF4E0) : const Color(0xFFFFF0F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.testName, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.secondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(item.value, style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)),
              const SizedBox(width: 4),
              Text(item.unit, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
              const Spacer(),
              Text('Range: ${item.referenceRange}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu, size: 14, color: AppColors.tertiary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

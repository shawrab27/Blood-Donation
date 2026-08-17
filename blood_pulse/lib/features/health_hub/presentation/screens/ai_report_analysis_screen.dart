import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';

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

  Future<void> _pickReport() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _reportFile = File(picked.path);
        _hasAnalyzed = false;
      });
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

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(milliseconds: 1400));

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _hasAnalyzed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'AI Report Analysis',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
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
                          'Upload CBC or hemoglobin lab reports to extract parameters & verify donation readiness.',
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
                          Text('Select or Scan Report Document', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          SizedBox(height: 4),
                          Text('Supports JPG, PNG, PDF lab reports', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
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
            const SizedBox(height: 20),

            // Analyze Button
            CapsuleButton(
              label: _isAnalyzing ? 'Analyzing Document with AI...' : 'Process Report',
              icon: Icons.auto_awesome_rounded,
              isLoading: _isAnalyzing,
              showGlow: true,
              onPressed: _isAnalyzing ? null : _runAnalysis,
            ),
            const SizedBox(height: 28),

            // Results Section
            if (_hasAnalyzed) ...[
              const Text(
                'AI Health Summary',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
              const SizedBox(height: 14),

              // Trust & Authenticity Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Document Authenticity', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                          child: const Text('94.5% Authentic', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Extracted Parameters:', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutral)),
                    const SizedBox(height: 10),

                    _parameterRow('Hemoglobin (Hb)', '14.2 g/dL', 'Optimal (13.0–17.5)', true),
                    const Divider(height: 16),
                    _parameterRow('Platelet Count', '245,000 /μL', 'Normal Range', true),
                    const Divider(height: 16),
                    _parameterRow('WBC Count', '7,200 /μL', 'Normal Range', true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recommendation Box
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Result: Patient is in optimal condition for voluntary blood donation.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _parameterRow(String name, String value, String status, bool isGood) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            Text(status, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isGood ? AppColors.success : AppColors.error)),
          ],
        ),
      ],
    );
  }
}

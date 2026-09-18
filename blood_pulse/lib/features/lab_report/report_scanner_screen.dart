import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';

class ReportScannerScreen extends StatefulWidget {
  const ReportScannerScreen({super.key});

  @override
  State<ReportScannerScreen> createState() => _ReportScannerScreenState();
}

class _ReportScannerScreenState extends State<ReportScannerScreen> {
  bool _isScanning = false;
  bool _isScanned = false;

  void _startScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _isScanning = false;
      _isScanned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showLogo: true,
        subtitle: 'AI Scanner',
        showBackButton: true,
        onBack: () => context.go('/dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verify Blood Safety', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Scan your latest lab reports to update your health profile using AI extraction.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 32),

            // Scanner UI
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border.all(color: _isScanned ? AppColors.success : Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isScanning
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryRed),
                          SizedBox(height: 16),
                          Text('AI analyzing hemoglobin & infectious diseases...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : _isScanned
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                            const SizedBox(height: 16),
                            Text('Report Verified Securely', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.success)),
                            const SizedBox(height: 8),
                            const Text('Hemoglobin: 14.2 g/dL\nDiseases: Negative', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.document_scanner, color: Colors.grey, size: 64),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _startScan,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Scan Document'),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 32),
            
            if (_isScanned)
              ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Update Profile with Data'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';

class NidVerificationScreen extends StatefulWidget {
  const NidVerificationScreen({super.key});

  @override
  State<NidVerificationScreen> createState() => _NidVerificationScreenState();
}

class _NidVerificationScreenState extends State<NidVerificationScreen> {
  XFile? _image;
  bool _isProcessing = false;
  bool _isVerified = false;

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    setState(() {
      _image = image;
      if (_image != null) {
        _processOCR();
      }
    });
  }

  void _simulateUploadAndOcr() {
    _pickImage(ImageSource.gallery);
  }

  void _processOCR() async {
    setState(() => _isProcessing = true);
    // Simulate Gemini OCR extraction
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _isProcessing = false;
      _isVerified = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NID successfully extracted and verified!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showLogo: true,
        subtitle: 'Verification',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload your National ID',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      _isVerified ? Icons.check_circle : Icons.credit_card,
                      size: 64,
                      color: _isVerified ? Colors.green : AppColors.primaryRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isVerified ? 'OCR Parsing Successful' : 'Upload Front & Back Image',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else if (_isVerified)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  context.go('/donor_reg');
                },
                child: const Text('Proceed to Profile Setup'),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _simulateUploadAndOcr,
                child: const Text('Upload Images'),
              ),
          ],
        ),
      ),
    );
  }
}

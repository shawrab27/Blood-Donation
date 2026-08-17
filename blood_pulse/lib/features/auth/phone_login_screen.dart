import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nidController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  bool _hasNidImage = false;

  void _sendOtp() async {
    if (_phoneController.text.length < 10) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
  }

  void _verifyAndContinue() async {
    if (_otpController.text.length < 6 || _nidController.text.isEmpty || !_hasNidImage) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (mounted) {
      context.go('/register');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text('National Security Protocols Active', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.success)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Secure Access',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'To maintain the integrity of our national blood supply, all donors must verify their identity via the National ID (NID) system.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              // Security Badges
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lock, color: AppColors.success, size: 20),
                            const SizedBox(height: 8),
                            Text('End-to-End\nEncrypted Pipeline', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.security, color: AppColors.success, size: 20),
                            const SizedBox(height: 8),
                            Text('Verified by\nGovernment Gateway', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Phone Input
              Text('Phone Number', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_otpSent,
                decoration: const InputDecoration(
                  prefixText: '+880 ',
                  hintText: '1XXXXXXXXX',
                ),
              ),
              const SizedBox(height: 16),
              if (!_otpSent)
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),

              if (_otpSent) ...[
                const SizedBox(height: 24),
                Text('Verification Code', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '------',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('National ID (NID) Number', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Icon(Icons.lock, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('AES-256 Encrypted', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nidController,
                  keyboardType: TextInputType.number,
                  maxLength: 17,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge, color: Colors.grey),
                    hintText: 'Enter 10 or 17 digit NID',
                  ),
                ),
                const SizedBox(height: 24),
                Text('Upload NID Image (Front)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    // Simulate image picking
                    setState(() => _hasNidImage = true);
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      border: Border.all(color: _hasNidImage ? AppColors.success : Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_hasNidImage ? Icons.check_circle : Icons.camera_alt, color: _hasNidImage ? AppColors.success : Colors.grey, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            _hasNidImage ? 'NID Image Attached' : 'Tap to scan NID',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _hasNidImage ? AppColors.success : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndContinue,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

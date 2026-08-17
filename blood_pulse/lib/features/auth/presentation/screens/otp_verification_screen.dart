import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/app_logo_slot.dart';
import '../providers/auth_notifier.dart';
import '../providers/otp_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onVerify() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    final verified = ref.read(otpStateProvider.notifier).verifyCode(code);
    if (verified) {
      // Set verified in auth notifier and proceed to dashboard
      ref.read(authProvider.notifier).authenticateDirectly(isOtpVerified: true);
      context.go('/dashboard');
    }
  }

  void _onSkip() {
    // Enter app unverified (bypass)
    ref.read(authProvider.notifier).authenticateDirectly(isOtpVerified: false);
    context.go('/dashboard');
  }

  void _onResend() {
    final otpState = ref.read(otpStateProvider);
    ref.read(otpStateProvider.notifier).sendOtp(
          primaryPhone: otpState.primaryPhone,
          secondaryPhone: otpState.secondaryPhone,
        );
    _codeCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpStateProvider);

    return ResponsiveLayout(
      backgroundColor: AppColors.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppLogoSlot(size: AppLogoSize.card),
              const SizedBox(height: 12),
              const Text(
                'Blood Pulse',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Security Verification',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'An OTP verification code was sent to:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.neutral,
                ),
              ),
              const SizedBox(height: 4),

              Text(
                otpState.sentToPhone.isNotEmpty ? otpState.sentToPhone : 'your registered number',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 20),

              // Fallback Alert Box
              if (otpState.primaryFailed)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB3AE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          otpState.error ?? 'Primary number unreachable. Rerouting SMS to secondary.',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Hint Code box (for testing ease)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🔑 Debug Hint: Enter code "${otpState.correctCode}" or "1234"',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // OTP field
              CustomInputField(
                controller: _codeCtrl,
                hint: 'Enter 4-Digit Code',
                prefixIcon: Icons.lock_open_rounded,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _onVerify(),
              ),
              const SizedBox(height: 12),

              // Countdown/Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    otpState.countdownSeconds > 0
                        ? 'Resend OTP in ${otpState.countdownSeconds}s'
                        : 'Did not receive code?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.neutral,
                    ),
                  ),
                  if (otpState.countdownSeconds == 0)
                    TextButton(
                      onPressed: _onResend,
                      child: const Text(
                        'Resend Now',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Button
              CapsuleButton(
                label: 'Verify Code',
                icon: Icons.check_circle_outline_rounded,
                showGlow: true,
                onPressed: _onVerify,
              ),
              const SizedBox(height: 16),

              // Server error / Skip fallback bypass option
              if (otpState.bypassAvailable || otpState.primaryFailed)
                TextButton(
                  onPressed: _onSkip,
                  child: const Text(
                    '⚠️ Skip Verification (Bypass)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tertiary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

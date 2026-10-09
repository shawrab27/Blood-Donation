// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/blood_hub_v2_api_service.dart';
import '../widgets/requisition/email_otp_keypad.dart';

/// Screen 3.5: EmailOtpScreen (strictly 6-digit email OTP; no WhatsApp/SMS tabs).
/// Upon successful verification, transitions requisition state to OPEN and proceeds to PosterEditor.
class EmailOtpScreen extends ConsumerStatefulWidget {
  const EmailOtpScreen({
    super.key,
    this.requestId,
    this.patientName,
    this.bloodGroup,
    this.urgencyLevel,
    this.hospitalLocation,
    this.contactNumber,
    this.email,
    this.returnRoute = '/blood-hub/poster',
  });

  final int? requestId;
  final String? patientName;
  final String? bloodGroup;
  final String? urgencyLevel;
  final String? hospitalLocation;
  final String? contactNumber;
  final String? email;
  final String returnRoute;

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  int _countdown = 60;
  Timer? _timer;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _statusMessage;

  String get _currentPin => _pinControllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onKeypadTap(String value) {
    for (int i = 0; i < 6; i++) {
      if (_pinControllers[i].text.isEmpty) {
        _pinControllers[i].text = value;
        if (i < 5) {
          _pinFocusNodes[i + 1].requestFocus();
        }
        setState(() {});
        if (i == 5) {
          _verifyAndProceed();
        }
        break;
      }
    }
  }

  void _onKeypadBackspace() {
    for (int i = 5; i >= 0; i--) {
      if (_pinControllers[i].text.isNotEmpty) {
        _pinControllers[i].clear();
        _pinFocusNodes[i].requestFocus();
        setState(() {});
        break;
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0 || _isSending) return;
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      if (widget.requestId != null) {
        await ref
            .read(bloodHubV2ApiServiceProvider)
            .sendOtp(widget.requestId!, email: widget.email);
      } else {
        final email = widget.email ?? ref.read(authProvider).user?.email ?? '';
        await ref.read(authProvider.notifier).sendVerificationEmail(email: email);
      }
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _statusMessage = '✓ 6-Digit code dispatched to your email.';
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _statusMessage = 'Failed to resend code: $e';
      });
    }
  }

  Future<void> _verifyAndProceed() async {
    final code = _currentPin;
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 6 digits of the code.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      if (widget.requestId != null) {
        await ref
            .read(bloodHubV2ApiServiceProvider)
            .verifyOtp(widget.requestId!, code);
      } else {
        final email = widget.email ?? ref.read(authProvider).user?.email ?? '';
        final ok = await ref
            .read(authProvider.notifier)
            .verifyEmailCode(code: code, email: email);
        if (!ok) throw Exception('Invalid OTP code');
      }

      if (!mounted) return;
      setState(() => _isVerifying = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Email verified! Requisition broadcasted to matching donors.'),
          backgroundColor: Color(0xFF1B8A4E),
        ),
      );

      context.go(
        widget.returnRoute,
        extra: {
          'requestId': widget.requestId,
          'patientName': widget.patientName ?? 'Urgent Patient',
          'bloodGroup': widget.bloodGroup ?? 'O+',
          'urgencyLevel': widget.urgencyLevel ?? 'CRITICAL',
          'hospitalLocation': widget.hospitalLocation ?? 'Medical Center',
          'contactNumber': widget.contactNumber ?? '',
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = widget.email ??
        ref.watch(authProvider).user?.email ??
        'your registered email';

    return ResponsiveCenterWrapper(
      maxWidth: 500,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE9EB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Verify Your Requisition',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(height: 6),
            Text(
              'A 6-digit confirmation code was sent to:\n$userEmail',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            EmailOtpPinRow(controllers: _pinControllers),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _countdown > 0 ? 'Resend code in ${_countdown}s' : 'Didn\'t get the code?',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                ),
                if (_countdown == 0)
                  TextButton(
                    onPressed: _isSending ? null : _resendOtp,
                    child: Text(
                      _isSending ? 'Sending...' : 'Resend Code',
                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            CapsuleButton(
              label: 'Verify & Continue',
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : _verifyAndProceed,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            const SizedBox(height: 24),
            EmailOtpKeypad(
              onDigit: _onKeypadTap,
              onBackspace: _onKeypadBackspace,
            ),
          ],
        ),
      ),
    );
  }
}

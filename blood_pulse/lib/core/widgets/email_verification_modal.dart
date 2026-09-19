import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../widgets/capsule_button.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// Modal dialog/bottom sheet prompting the user to verify their email address
/// before submitting an emergency blood request.
class EmailVerificationModal extends ConsumerStatefulWidget {
  final String? initialEmail;

  const EmailVerificationModal({super.key, this.initialEmail});

  /// Static helper to display the modal bottom sheet
  static Future<bool?> show(BuildContext context, {String? initialEmail}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmailVerificationModal(initialEmail: initialEmail),
    );
  }

  @override
  ConsumerState<EmailVerificationModal> createState() =>
      _EmailVerificationModalState();
}

class _EmailVerificationModalState
    extends ConsumerState<EmailVerificationModal> {
  late final TextEditingController _emailCtrl;
  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  int _countdown = 45;
  Timer? _timer;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final defaultEmail =
        widget.initialEmail ?? user?.email ?? '';
    _emailCtrl = TextEditingController(text: defaultEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 45);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _statusError = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _statusError = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .sendVerificationEmail(email: email);

    if (!mounted) return;

    setState(() => _isSendingCode = false);

    if (success) {
      setState(() => _codeSent = true);
      _startCountdown();
      _pinFocusNodes.first.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('6-digit code sent to $email.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final err = ref.read(authProvider).errorMessage ??
          'Failed to send verification code. Please check email.';
      setState(() => _statusError = err);
    }
  }

  Future<void> _verifyCode() async {
    final code = _pinControllers.map((c) => c.text).join().trim();
    if (code.length != 6) {
      setState(() => _statusError = 'Please enter all 6 digits of the code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusError = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .verifyEmailCode(code: code, email: _emailCtrl.text.trim());

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Email successfully verified! You may now submit your request.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final err = ref.read(authProvider).errorMessage ??
          'Invalid or expired code. Please try again.';
      setState(() => _statusError = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Pill Handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Verification',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Required before broadcasting emergency request',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Explanatory note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To protect patients and donors from spam and unauthorized broadcasts, a quick email verification is mandatory before your first emergency request.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: AppColors.neutral,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Email input field
            const Text(
              'Your Email Address',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. donor@gmail.com',
                prefixIcon: const Icon(Icons.email_outlined,
                    size: 20, color: AppColors.neutral),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Send / Resend Code Button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isSendingCode || _countdown > 0 && _codeSent)
                        ? null
                        : _sendCode,
                    icon: _isSendingCode
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : Icon(
                            _codeSent
                                ? Icons.replay_rounded
                                : Icons.send_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                    label: Text(
                      _codeSent
                          ? (_countdown > 0
                              ? 'Resend Code in ${_countdown}s'
                              : 'Resend Verification Code')
                          : 'Send 6-Digit Code',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // PIN Boxes
            const Text(
              'Enter 6-Digit Verification Code',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 46,
                  height: 52,
                  child: TextField(
                    controller: _pinControllers[index],
                    focusNode: _pinFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFFDF3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF9D2D7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF9D2D7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty && index < 5) {
                        _pinFocusNodes[index + 1].requestFocus();
                      } else if (val.isEmpty && index > 0) {
                        _pinFocusNodes[index - 1].requestFocus();
                      }
                      if (index == 5 && val.isNotEmpty) {
                        // Auto trigger verify on last digit
                        _verifyCode();
                      }
                    },
                  ),
                );
              }),
            ),

            if (_statusError != null) ...[
              const SizedBox(height: 10),
              Text(
                _statusError!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Verify & Proceed Capsule Button
            CapsuleButton(
              label: _isVerifying ? 'Verifying...' : 'Verify & Continue',
              icon: Icons.check_circle_rounded,
              isLoading: _isVerifying,
              onPressed: _verifyCode,
            ),
          ],
        ),
      ),
    );
  }
}

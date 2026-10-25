import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:blood_pulse/core/errors/app_error_mapper.dart';
import 'package:blood_pulse/services/api_client.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/password_strength_meter.dart';
import '../providers/auth_notifier.dart';

import 'package:blood_pulse/core/enums/otp_delivery_state.dart';
export 'package:blood_pulse/core/enums/otp_delivery_state.dart';

class VerifyOtpResetScreen extends ConsumerStatefulWidget {
  final String email;
  final OtpDeliveryState? initialDeliveryState;

  const VerifyOtpResetScreen({
    super.key,
    required this.email,
    this.initialDeliveryState,
  });

  @override
  ConsumerState<VerifyOtpResetScreen> createState() => _VerifyOtpResetScreenState();
}

class _VerifyOtpResetScreenState extends ConsumerState<VerifyOtpResetScreen>
    with SingleTickerProviderStateMixin {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  late OtpDeliveryState _deliveryState;
  String? _errorMessage;
  int _countdown = 45;
  Timer? _timer;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _deliveryState = widget.initialDeliveryState ?? OtpDeliveryState.sent;
    _startTimer();

    _passwordCtrl.addListener(_onFieldChanged);
    _confirmCtrl.addListener(_onFieldChanged);
    for (var ctrl in _otpControllers) {
      ctrl.addListener(_onFieldChanged);
    }

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _isFormValid {
    if (_isLoading) return false;
    if (_otpCode.length != 6) return false;
    if (_passwordCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) return false;
    if (_passwordCtrl.text != _confirmCtrl.text) return false;
    return true;
  }

  void _startTimer() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _passwordCtrl.removeListener(_onFieldChanged);
    _confirmCtrl.removeListener(_onFieldChanged);
    for (var ctrl in _otpControllers) {
      ctrl.removeListener(_onFieldChanged);
    }
    _shakeController.dispose();
    for (var ctrl in _otpControllers) {
      ctrl.dispose();
    }
    for (var node in _otpNodes) {
      node.dispose();
    }
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  String _obscuredEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final user = parts[0];
    final domain = parts[1];
    if (user.isEmpty) return '***@$domain';
    return '${user[0]}***@$domain';
  }

  void _shakeAndClear() {
    _shakeController.forward(from: 0);
    for (var ctrl in _otpControllers) {
      ctrl.clear();
    }
    _otpNodes[0].requestFocus();
  }

  void _handleOtpInput(String value, int index) {
    if (value.length > 1) {
      final paste = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < paste.length && i < 6; i++) {
        _otpControllers[i].text = paste[i];
      }
      if (paste.length < 6) {
        _otpNodes[paste.length].requestFocus();
      } else {
        _otpNodes[5].unfocus();
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _otpNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == 5) {
      _otpNodes[index].unfocus();
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _deliveryState = OtpDeliveryState.sending;
      _errorMessage = null;
    });

    int attempt = 0;
    while (attempt < 2) {
      attempt++;
      try {
        await ApiClient()
            .requestOtp(widget.email)
            .timeout(const Duration(seconds: 8));
        _startTimer();
        if (!mounted) return;
        setState(() {
          _deliveryState = OtpDeliveryState.sent;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your email!', style: TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: StadiumBorder(),
          ),
        );
        return;
      } catch (e) {
        if (attempt == 1) {
          continue; // One auto-retry on failure
        }
        if (!mounted) return;
        setState(() {
          _deliveryState = OtpDeliveryState.failure;
          _errorMessage = AppError.toHumanMessage(e);
          _isLoading = false;
        });
        return;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final otp = _otpCode;
    if (otp.length != 6) {
      _shakeAndClear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 6 digits of the OTP code',
              style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
      return;
    }

    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: StadiumBorder(),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiClient().confirmReset(widget.email, otp, _passwordCtrl.text);
      if (!mounted) return;

      // Automatically sign in with new credentials
      final signedIn = await ref.read(authProvider.notifier).loginWithCredentials(
            identifier: widget.email,
            password: _passwordCtrl.text,
          );

      if (!mounted) return;
      if (signedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Welcome back.',
                style: TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: StadiumBorder(),
          ),
        );
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful. Please sign in.',
                style: TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: StadiumBorder(),
          ),
        );
        context.go('/login');
      }
    } on OtpWrongException catch (e) {
      if (!mounted) return;
      _shakeAndClear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : 'Unable to complete password reset. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PressableScale(child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
          onPressed: () => context.pop(),
        )),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'BloodPulse',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Subheader link: < Change Email Address ───────
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/forgot-password');
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.neutral),
                        SizedBox(width: 4),
                        Text(
                          'Change Email Address',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.neutral,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Main Card ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E7D7F).withAlpha(22),
                          blurRadius: 24,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          // ── Title: Verify OTP Code ───────────────
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                              children: [
                                TextSpan(text: 'Verify '),
                                TextSpan(
                                  text: 'OTP',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                                TextSpan(text: ' Code'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_deliveryState == OtpDeliveryState.sending) ...[
                            Container(
                              key: const Key('otp_state_sending'),
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: const Column(
                                children: [
                                  AppLoader.small(),
                                  SizedBox(height: 14),
                                  Text(
                                    'Sending verification code...',
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF666666)),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_deliveryState == OtpDeliveryState.failure) ...[
                            Container(
                              key: const Key('otp_state_failure'),
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECEE),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF5C8D0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFC30121), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage ?? 'Unable to send code. Please try again.',
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFFC30121)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  PressableScale(child: ElevatedButton.icon(
                                    key: const Key('otp_retry_button'),
                                    onPressed: _resendOtp,
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC30121),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ] else ...[
                            Column(
                              key: const Key('otp_state_sent'),
                              children: [
                                Text(
                                  'Code sent to ${_obscuredEmail(widget.email)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B2B2B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/forgot-password');
                                        }
                                      },
                                      child: const Text(
                                        '(Edit Email)',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                AnimatedBuilder(
                                  animation: _shakeAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                          math.sin(_shakeAnimation.value * math.pi) * 10, 0),
                                      child: child,
                                    );
                                  },
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: OtpInputRow(
                                      controllers: _otpControllers,
                                      nodes: _otpNodes,
                                      fillColor: const Color(0xFFFDEAEB),
                                      onChanged: _handleOtpInput,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        size: 15, color: Color(0xFF888888)),
                                    const SizedBox(width: 6),
                                    if (_countdown > 0)
                                      Text(
                                        'Resend OTP in 00:${_countdown.toString().padLeft(2, '0')}s',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                    if (_countdown == 0)
                                      GestureDetector(
                                        onTap: _resendOtp,
                                        child: const Text(
                                          'Resend OTP',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 28),

                          // ── New Password Section ─────────────────
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'New Password',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'Min. 8 characters',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '••••••••••••',
                              hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded, color: AppColors.tertiary),
                              suffixIcon: PressableScale(child: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF888888),
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              )),
                              filled: true,
                              fillColor: const Color(0xFFFFF8F7),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: const BorderSide(color: Color(0xFFF0D5D7)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide:
                                    const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide:
                                    const BorderSide(color: AppColors.error, width: 1.5),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          PasswordStrengthMeter(controller: _passwordCtrl),
                          const SizedBox(height: 18),

                          // ── Confirm New Password Section ─────────
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Confirm New Password',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '••••••••••••',
                              hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded, color: AppColors.tertiary),
                              suffixIcon: PressableScale(child: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF888888),
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureConfirm = !_obscureConfirm),
                              )),
                              filled: true,
                              fillColor: const Color(0xFFFFF8F7),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: const BorderSide(color: Color(0xFFF0D5D7)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide:
                                    const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide: const BorderSide(color: AppColors.error),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                                borderSide:
                                    const BorderSide(color: AppColors.error, width: 1.5),
                              ),
                            ),
                            validator: (v) {
                              if (v != _passwordCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // ── Submit Button ────────────────────────
                          CapsuleButton(
                            label: 'Reset Password & Sign In',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _isFormValid ? _submit : null,
                            isLoading: _isLoading,
                            showGlow: true,
                            height: 52,
                          ),
                          const SizedBox(height: 20),

                          // ── Cancel Link ──────────────────────────
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(Icons.close_rounded, size: 16, color: Color(0xFF888888)),
                                SizedBox(width: 6),
                                Text(
                                  'Cancel and return to Login',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Support Footer ───────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          "Didn't receive an SMS or email?",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF777777),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please email support@bloodpulse.org or call 16263 for donor support.',
                                  style: TextStyle(fontFamily: 'Inter'),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(Icons.support_agent_rounded, size: 16, color: AppColors.tertiary),
                              SizedBox(width: 4),
                              Text(
                                'Contact BloodPulse Donor Support',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 + MediaQuery.viewPaddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

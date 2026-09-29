import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';
import 'package:blood_pulse/core/widgets/brand_logo.dart';
import 'package:blood_pulse/services/api_client.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/password_strength_meter.dart';

class VerifyOtpResetScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyOtpResetScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpResetScreen> createState() => _VerifyOtpResetScreenState();
}

class _VerifyOtpResetScreenState extends ConsumerState<VerifyOtpResetScreen> with SingleTickerProviderStateMixin {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  int _countdown = 45;
  Timer? _timer;
  
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
  }

  void _startTimer() {
    setState(() => _countdown = 45);
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
    if (_countdown > 0) return;
    setState(() => _isLoading = true);
    try {
      await ApiClient().requestOtp(widget.email);
      _startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final otp = _otpCode;
    if (otp.length != 6) {
      _shakeAndClear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits'), backgroundColor: AppColors.error),
      );
      return;
    }
    
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await ApiClient().confirmReset(widget.email, otp, _passwordCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully'), backgroundColor: Colors.green),
      );
      while (context.canPop()) {
        context.pop();
      }
      context.pushReplacement('/login', extra: {'email': widget.email});
    } on OtpWrongException catch (e) {
      // Wrong / expired OTP from backend → shake boxes and clear them.
      if (!mounted) return;
      _shakeAndClear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } catch (e) {
      // Weak password, network error, 429, etc. → show error but KEEP OTP intact.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.secondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const BrandLogo(size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'Verification',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code sent to\n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.tertiary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(math.sin(_shakeAnimation.value * math.pi) * 10, 0),
                        child: child,
                      );
                    },
                    child: OtpInputRow(
                      controllers: _otpControllers,
                      nodes: _otpNodes,
                      onChanged: _handleOtpInput,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.tertiary),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  PasswordStrengthMeter(controller: _passwordCtrl),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.tertiary),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: Listenable.merge([_passwordCtrl, _confirmCtrl]),
                    builder: (context, child) {
                      final bool canSubmit = _passwordCtrl.text.isNotEmpty && _passwordCtrl.text == _confirmCtrl.text;
                      return CapsuleButton(
                        label: 'Verify & Save',
                        onPressed: canSubmit ? _submit : null,
                        isLoading: _isLoading,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _countdown > 0 ? null : _resendOtp,
                    child: Text(
                      _countdown > 0
                          ? 'Resend OTP in  seconds'
                          : 'Resend OTP',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: _countdown > 0 ? AppColors.tertiary : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


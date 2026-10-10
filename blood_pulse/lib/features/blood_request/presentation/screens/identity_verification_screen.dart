// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../services/api_client.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../blood_hub/data/blood_hub_api_service.dart';
import '../providers/blood_request_provider.dart';

enum VerificationMethod { email, whatsapp, sms }

/// Stitch Screen 5 (ID: 4166edee3c5d4dfd9f3af4e3b2936eeb)
/// Identity Verification - Multi-Channel OTP Gate
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({
    super.key,
    this.patientName,
    this.bloodGroup,
    this.urgencyLevel,
    this.hospitalLocation,
    this.contactNumber,
    this.email,
    this.condition,
    this.emergencyPayload,
    this.returnRoute = '/live-dispatch',
    this.apiClient,
    this.autoSend = true,
  });

  final String? patientName;
  final String? bloodGroup;
  final String? urgencyLevel;
  final String? hospitalLocation;
  final String? contactNumber;
  final String? email;
  final String? condition;
  final Map<String, dynamic>? emergencyPayload;
  final String returnRoute;
  final ApiClient? apiClient;
  final bool autoSend;

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  VerificationMethod _selectedMethod = VerificationMethod.email;

  late final TextEditingController _emailCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _smsCtrl;

  final List<TextEditingController> _pinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (_) => FocusNode());

  late final ApiClient _apiClient;

  int _countdown = 60;
  Timer? _timer;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    final authUser = ref.read(authProvider).user;
    final initialEmail = widget.email ??
        (authUser?.email.isNotEmpty == true ? authUser!.email : '');
    final initialPhone = widget.contactNumber ?? authUser?.primaryPhone ?? '';

    _emailCtrl = TextEditingController(text: initialEmail);
    _whatsappCtrl = TextEditingController(text: initialPhone);
    _smsCtrl = TextEditingController(text: initialPhone);

    _startCountdown();

    // Auto-dispatch verification OTP upon arriving at verification gate
    if (widget.autoSend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _emailCtrl.text.trim().isNotEmpty) {
          _sendOtp();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _whatsappCtrl.dispose();
    _smsCtrl.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _countdown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentPin => _pinControllers.map((c) => c.text).join();

  void _onMethodSelected(VerificationMethod method) {
    if (method == VerificationMethod.whatsapp) {
      _showComingSoonDialog('WhatsApp Verification', 'WhatsApp OTP verification is coming soon. Please verify using Email.');
      return;
    }
    if (method == VerificationMethod.sms) {
      _showComingSoonDialog('Phone Number Verification', 'SMS phone number verification is coming soon. Please verify using Email.');
      return;
    }
    setState(() => _selectedMethod = method);
  }

  void _showComingSoonDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onKeypadTap(String value) {
    for (int i = 0; i < 6; i++) {
      if (_pinControllers[i].text.isEmpty) {
        _pinControllers[i].text = value;
        if (i < 5) {
          _pinFocusNodes[i + 1].requestFocus();
        }
        setState(() {});
        
        // Auto-verify when 6th digit is entered
        if (i == 5) {
          _verifyAndSubmit();
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

  void _handlePinChanged(int index, String value) {
    if (value.length > 1) {
      // Paste support: user pasted a 6-digit code or text containing digits
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < 6 && i < digits.length; i++) {
          _pinControllers[i].text = digits[i];
        }
        final nextIndex = digits.length < 6 ? digits.length : 5;
        _pinFocusNodes[nextIndex].requestFocus();
        setState(() {});
        if (digits.length >= 6) {
          _verifyAndSubmit();
        }
        return;
      }
    }

    if (value.isNotEmpty && index < 5) {
      _pinFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }
    setState(() {});

    if (_currentPin.length == 6) {
      _verifyAndSubmit();
    }
  }

  Future<void> _sendOtp() async {
    if (_isSending) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final res = await _apiClient.sendRequestOtp(email: email);
      final cooldown = (res['cooldown_seconds'] as num?)?.toInt() ?? 60;
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _statusMessage = 'Verification code dispatched to $email';
        _errorMessage = null;
      });
      _startCountdown(cooldown);
    } on RequestOtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.message;
      });
      if (e.cooldownSeconds != null && e.cooldownSeconds! > 0) {
        _startCountdown(e.cooldownSeconds!);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorMessage = 'Network connection failed. Please check your internet connection.';
      });
    }
  }

  Future<void> _verifyAndSubmit() async {
    if (_isVerifying) return;
    final code = _currentPin;
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Please enter the full 6-digit verification code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final email = _emailCtrl.text.trim();
    String? submitToken;

    try {
      submitToken = await _apiClient.verifyRequestOtp(
        code: code,
        email: email,
      );
    } on RequestOtpException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message;
      });
      for (final c in _pinControllers) {
        c.clear();
      }
      _pinFocusNodes[0].requestFocus();
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message;
      });
      for (final c in _pinControllers) {
        c.clear();
      }
      _pinFocusNodes[0].requestFocus();
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Network connection failed. Please check your internet connection.';
      });
      return;
    }

    // After the correct email OTP, the request is sent with the submit_token
    try {
      bool submitSuccess = false;
      if (widget.emergencyPayload != null) {
        final payload = Map<String, dynamic>.from(widget.emergencyPayload!);
        payload['submit_token'] = submitToken;
        final res = await ref.read(bloodHubApiServiceProvider).createEmergencyRequest(payload);
        submitSuccess = res.containsKey('id');
      } else if (widget.patientName != null && widget.bloodGroup != null) {
        submitSuccess = await ref.read(bloodRequestProvider.notifier).createRequest(
          patientName: widget.patientName!,
          bloodGroup: widget.bloodGroup!,
          urgencyLevel: widget.urgencyLevel ?? 'Critical',
          hospitalLocation: widget.hospitalLocation ?? 'City General Hospital',
          contactNumber: widget.contactNumber ??
              ref.read(authProvider).user?.primaryPhone ??
              '',
          submitToken: submitToken,
        );
      } else {
        submitSuccess = true;
      }

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (!submitSuccess) {
        final err = ref.read(bloodRequestProvider).errorMessage ?? 'Failed to submit blood request.';
        setState(() {
          _errorMessage = err;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identity verified! Request broadcasted successfully.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (mounted) {
        context.go(
          widget.returnRoute,
          extra: {
            'patientName': widget.patientName ?? 'Emergency Requester',
            'hospitalName': widget.hospitalLocation ?? 'Medical Center',
            'bloodGroup': widget.bloodGroup ?? '',
            'donorName': '',
            'donorPhone': '',
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Request submission failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: BloodPulseAppBar(
        showBackButton: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Subtitle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Identity Verification',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFFC30121)),
                        label: const Text('Need help?', style: TextStyle(color: Color(0xFFC30121), fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => context.push('/assistant', extra: 'IDENTITY_VERIFICATION'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To protect patient safety and prevent fake requests, please verify your identity via email OTP before broadcasting.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF5C3F3D),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Method Switcher (Email / WhatsApp / Phone)
                  const Text(
                    'Select Verification Method',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C3F3D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      children: [
                        _buildMethodTab(
                          method: VerificationMethod.email,
                          icon: Icons.mail_outline_rounded,
                          label: 'Email',
                        ),
                        _buildMethodTab(
                          method: VerificationMethod.whatsapp,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'WhatsApp',
                        ),
                        _buildMethodTab(
                          method: VerificationMethod.sms,
                          icon: Icons.phone_android_rounded,
                          label: 'Phone',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Destination Input & Send OTP Button
                  _buildMethodInputSection(),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1F8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF0D68AA).withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: Color(0xFF0D68AA)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D68AA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEE),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFC30121).withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 18, color: Color(0xFFC30121)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC30121),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 6-Digit PIN Boxes
                  const Center(
                    child: Text(
                      'Enter 6-Digit OTP',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5C3F3D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPinRow(),

                  const SizedBox(height: 12),

                  // Resend Timer
                  Center(
                    child: GestureDetector(
                      onTap: (_countdown == 0 && !_isSending) ? _sendOtp : null,
                      child: Text(
                        _countdown > 0
                            ? 'Resend code in 00:${_countdown.toString().padLeft(2, '0')}'
                            : 'Didn’t receive code? Resend Code',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _countdown > 0
                              ? const Color(0xFF004B7E)
                              : const Color(0xFFC30121),
                          decoration: _countdown == 0
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Primary Action Capsule Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: CapsuleButton(
                      label: _isVerifying
                          ? 'Verifying...'
                          : 'Verify & Submit Request ➔',
                      isLoading: _isVerifying,
                      showGlow: true,
                      onPressed: _isVerifying ? () {} : _verifyAndSubmit,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Virtual Keypad
                  _buildVirtualKeypad(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTab({
    required VerificationMethod method,
    required IconData icon,
    required String label,
  }) {
    final isActive = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onMethodSelected(method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFC30121) : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? Colors.white : const Color(0xFF5C3F3D),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : const Color(0xFF5C3F3D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C3F3D),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xFFE6BDBA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded, size: 20, color: Color(0xFF888888)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF2B2B2B),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter your email address',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_isSending || _countdown > 0) ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004B7E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _countdown > 0 ? '${_countdown}s' : 'Send Code',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = ((constraints.maxWidth - 40) / 6).clamp(34.0, 48.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final isFilled = _pinControllers[index].text.isNotEmpty;
            return SizedBox(
              width: boxWidth,
              height: 54,
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC30121),
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: isFilled ? const Color(0xFFFFF0F1) : Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE6BDBA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF004B7E), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      isFilled ? const Color(0xFFC30121) : const Color(0xFFE6BDBA),
                ),
              ),
            ),
            onChanged: (val) => _handlePinChanged(index, val),
          ),
        );
      }),
    );
      },
    );
  }

  Widget _buildVirtualKeypad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6BDBA).withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton('1'),
              _buildKeypadButton('2'),
              _buildKeypadButton('3'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton('4'),
              _buildKeypadButton('5'),
              _buildKeypadButton('6'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKeypadButton('7'),
              _buildKeypadButton('8'),
              _buildKeypadButton('9'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const SizedBox(width: 60, height: 48),
              _buildKeypadButton('0'),
              _buildKeypadButton(
                '',
                icon: Icons.backspace_outlined,
                onTap: _onKeypadBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(
    String label, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 60,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap ?? () => _onKeypadTap(label),
          child: Center(
            child: icon != null
                ? Icon(icon, color: const Color(0xFFBA1A1A), size: 22)
                : Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

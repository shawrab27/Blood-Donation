import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
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
    this.returnRoute = '/live-dispatch',
  });

  final String? patientName;
  final String? bloodGroup;
  final String? urgencyLevel;
  final String? hospitalLocation;
  final String? contactNumber;
  final String returnRoute;

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

  int _countdown = 45;
  Timer? _timer;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authProvider).user;
    final initialEmail = authUser?.email.isNotEmpty == true
        ? authUser!.email
        : 'user@example.com';
    final initialPhone = authUser?.primaryPhone ?? '+8801700000000';

    _emailCtrl = TextEditingController(text: initialEmail);
    _whatsappCtrl = TextEditingController(text: initialPhone);
    _smsCtrl = TextEditingController(text: initialPhone);

    _startCountdown();
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

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 45);
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

  void _onKeypadTap(String value) {
    for (int i = 0; i < 6; i++) {
      if (_pinControllers[i].text.isEmpty) {
        _pinControllers[i].text = value;
        if (i < 5) {
          _pinFocusNodes[i + 1].requestFocus();
        }
        setState(() {});
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

  Future<void> _sendOtp() async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    final email = _emailCtrl.text.trim();
    final success =
        await ref.read(authProvider.notifier).sendVerificationEmail(email: email);

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _statusMessage = success
          ? 'Verification code dispatched to $email'
          : 'Failed to send OTP. Please try again.';
    });
    _startCountdown();
  }

  Future<void> _verifyAndSubmit() async {
    final code = _currentPin;
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full 6-digit OTP.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    final email = _emailCtrl.text.trim();
    // Verify against backend
    final ok = await ref.read(authProvider.notifier).verifyEmailCode(
          code: code,
          email: email,
        );

    if (!mounted) return;

    if (ok) {
      // If we received blood request details, create request
      if (widget.patientName != null && widget.bloodGroup != null) {
        await ref.read(bloodRequestProvider.notifier).createRequest(
              patientName: widget.patientName!,
              bloodGroup: widget.bloodGroup!,
              urgencyLevel: widget.urgencyLevel ?? 'Critical',
              hospitalLocation: widget.hospitalLocation ?? 'City General Hospital',
              contactNumber: widget.contactNumber ?? '+8801700000000',
            );
        if (!mounted) return;
      }

      setState(() => _isVerifying = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identity verified successfully!'),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate straight into Screen 6 (Live Dispatch & Step Tracking)
      if (mounted) {
        context.go(
          widget.returnRoute,
          extra: {
            'patientName': widget.patientName ?? 'Emergency Requester',
            'hospitalName': widget.hospitalLocation ?? 'Medical Center',
            'bloodGroup': widget.bloodGroup ?? '',
            'donorName': 'Matched Volunteer Donor',
            'donorPhone': '',
          },
        );
      }
    } else {
      setState(() => _isVerifying = false);
      final error = ref.read(authProvider).errorMessage ??
          'Invalid or expired code. (Tip: Demo code is 421234)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                  const Text(
                    'Identity Verification',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To ensure patient safety, please verify your identity via OTP. This is required for users without a verified NID/Birth Certificate.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF5C3F3D),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Method Switcher (Email / WhatsApp / SMS)
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
                          icon: Icons.sms_outlined,
                          label: 'SMS',
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
                      onTap: _countdown == 0 ? _sendOtp : null,
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
        onTap: () => setState(() => _selectedMethod = method),
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
    String label = 'Email Address';
    String hint = 'Enter your email';
    IconData icon = Icons.mail_outline_rounded;
    TextEditingController ctrl = _emailCtrl;
    TextInputType keyboard = TextInputType.emailAddress;

    if (_selectedMethod == VerificationMethod.whatsapp) {
      label = 'WhatsApp Number';
      hint = 'Enter WhatsApp phone number';
      icon = Icons.chat_bubble_outline_rounded;
      ctrl = _whatsappCtrl;
      keyboard = TextInputType.phone;
    } else if (_selectedMethod == VerificationMethod.sms) {
      label = 'Phone Number';
      hint = 'Enter SMS phone number';
      icon = Icons.phone_android_rounded;
      ctrl = _smsCtrl;
      keyboard = TextInputType.phone;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
              Icon(icon, size: 20, color: const Color(0xFF888888)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboard,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF2B2B2B),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
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
                onPressed: _isSending ? null : _sendOtp,
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
                    : const Text(
                        'Send OTP',
                        style: TextStyle(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        final isFilled = _pinControllers[index].text.isNotEmpty;
        return SizedBox(
          width: 46,
          height: 54,
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
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
            onChanged: (val) {
              if (val.isNotEmpty && index < 5) {
                _pinFocusNodes[index + 1].requestFocus();
              } else if (val.isEmpty && index > 0) {
                _pinFocusNodes[index - 1].requestFocus();
              }
              setState(() {});
            },
          ),
        );
      }),
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

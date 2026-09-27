// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../services/api_client.dart';
import '../providers/auth_notifier.dart';

/// Login Screen — Phone/Username + Password.
///
/// Rules enforced:
///   • NO OTP on login (per spec)
///   • Validation via Flutter [Form]
///   • Navigates to /dashboard on success
///   • "Create an Account" link → /register
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _idFocus = FocusNode();
  final _pwFocus = FocusNode();

  // Subtle slide-up entry animation
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _entryCtrl.dispose();
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _idFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    _idFocus.unfocus();
    _pwFocus.unfocus();

    final success = await ref.read(authProvider.notifier).loginWithCredentials(
          identifier: _idCtrl.text.trim(),
          password: _pwCtrl.text,
        );

    if (!mounted) return;
    if (success) {
      context.go('/dashboard');
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Login failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err, style: const TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
        ),
      );
    }
  }

  Future<void> _onGoogleSignIn() async {
    _idFocus.unfocus();
    _pwFocus.unfocus();

    final success = await ref.read(authProvider.notifier).signInWithGoogle();

    if (!mounted) return;
    if (success) {
      final user = ref.read(authProvider).user;
      final bool isProfileComplete = user?.isProfileComplete == true &&
          (user?.bloodGroup.isNotEmpty ?? false) &&
          (user?.primaryPhone.isNotEmpty ?? false);
      if (isProfileComplete) {
        context.go('/dashboard');
      } else {
        context.go('/complete-profile');
      }
    } else {
      final err = ref.read(authProvider).errorMessage;
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err, style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
          ),
        );
      }
    }
  }

  void _openForgotPasswordSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ForgotPasswordModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMobile();
  }

  Widget _buildMobile() {
    final auth = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F3),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        // ── Official BloodPulse Logo & Brand Name ─────────
                        const BloodPulseLogo(
                          direction: Axis.vertical,
                          iconSize: 64.0,
                          fontSize: 32.0,
                          spacing: 12.0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n?.loginSubtitle ?? 'Welcome back to the community.\nYour donation matters.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.neutral,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        // ── Card ──────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(24),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Phone / Username ────────────────────────
                              _SectionLabel(l10n?.usernameOrPhone ?? 'Username or Phone'),
                              const SizedBox(height: 8),
                              CustomInputField(
                                controller: _idCtrl,
                                focusNode: _idFocus,
                                hint: l10n?.enterCredentials ?? 'Enter your credentials',
                                prefixIcon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.text,
                                onSubmitted: (_) =>
                                    FocusScope.of(context).requestFocus(_pwFocus),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? (l10n?.usernameOrPhone ?? 'Please enter your username or phone')
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              // ── Password ────────────────────────────────
                              _SectionLabel(l10n?.authPassword ?? 'Password'),
                              const SizedBox(height: 8),
                              CustomInputField(
                                controller: _pwCtrl,
                                focusNode: _pwFocus,
                                hint: '••••••••',
                                prefixIcon: Icons.lock_outline_rounded,
                                isPassword: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _onSignIn(),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return l10n?.authPassword ?? 'Password is required';
                                  }
                                  if (v.length < 6) {
                                    return 'At least 6 characters required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              // ── Forgot Password ─────────────────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () => _openForgotPasswordSheet(context),
                                  child: Text(
                                    l10n?.forgotPassword ?? 'Forgot password?',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.tertiary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // ── Sign In Button ──────────────────────────
                              CapsuleButton(
                                label: l10n?.signIn ?? 'Sign In',
                                icon: Icons.arrow_forward_rounded,
                                isLoading: auth.isLoading,
                                showGlow: true,
                                onPressed: auth.isLoading ? null : _onSignIn,
                              ),
                              const SizedBox(height: 20),
                              // ── Social Login Row (Mobile) ──
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Color(0xFFE2E2E2))),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'Or continue with',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Color(0xFFE2E2E2))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CapsuleButton(
                                label: 'Continue with Google',
                                isOutlined: true,
                                icon: Icons.g_mobiledata_rounded,
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.secondary,
                                isLoading: auth.isLoading,
                                height: 50,
                                onPressed: auth.isLoading ? null : _onGoogleSignIn,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // ── Register link ──────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n?.dontHaveAccount ?? "Don't have an account? ",
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.neutral,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/register'),
                              child: Text(
                                l10n?.createAccount ?? 'Create an Account',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.secondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ForgotPasswordModal extends ConsumerStatefulWidget {
  const _ForgotPasswordModal();

  @override
  ConsumerState<_ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends ConsumerState<_ForgotPasswordModal> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  
  int _step = 1;
  bool _isLoading = false;
  String _resetToken = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }
  
  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: isError ? AppColors.error : const Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onRequestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await ApiClient().requestEmailOtp(email);
      if (!mounted) return;
      setState(() {
        _step = 2;
        _isLoading = false;
      });
      _showSnack('Check your email for a 6-digit code', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(e.toString());
    }
  }

  Future<void> _onVerifyOtp() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final token = await ApiClient().verifyEmailOtp(email, code);
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = 3;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(e.toString());
    }
  }

  Future<void> _onResetPassword() async {
    final np = _newPwCtrl.text;
    final cp = _confirmPwCtrl.text;
    
    if (np.length < 8) {
      _showSnack('Password must be at least 8 characters');
      return;
    }
    if (np != cp) {
      _showSnack('Passwords do not match');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await ApiClient().resetPassword(_resetToken, np, cp);
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('Password updated — please sign in', isError: false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Reset Password',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 6),
          Text(
            _step == 1 
                ? 'Enter your registered email to receive a 6-digit OTP.' 
                : _step == 2
                    ? 'Enter the 6-digit OTP sent to your email.'
                    : 'Create a new password (min. 8 characters).',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
          ),
          const SizedBox(height: 20),
          if (_step == 1) ...[
            CustomInputField(
              controller: _emailCtrl,
              hint: 'Email Address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Send OTP Code',
              icon: Icons.send_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _onRequestOtp,
            ),
          ] else if (_step == 2) ...[
            CustomInputField(
              controller: _codeCtrl,
              hint: 'Enter 6-Digit OTP',
              prefixIcon: Icons.lock_clock_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Verify OTP',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _onVerifyOtp,
            ),
          ] else if (_step == 3) ...[
            CustomInputField(
              controller: _newPwCtrl,
              hint: 'New Password',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 14),
            CustomInputField(
              controller: _confirmPwCtrl,
              hint: 'Confirm Password',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Update Password',
              icon: Icons.save_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _onResetPassword,
            ),
          ],
        ],
      ),
    );
  }
}


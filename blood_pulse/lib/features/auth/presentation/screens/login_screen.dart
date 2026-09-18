import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/app_logo.dart';
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
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                        side: const BorderSide(color: Color(0xFFE2E2E2)),
                                      ),
                                      icon: const Icon(Icons.g_mobiledata, size: 20, color: Color(0xFF2B2B2B)),
                                      label: const Text(
                                        'Google',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2B2B2B)),
                                      ),
                                      onPressed: () async {
                                        final success = await ref.read(authProvider.notifier).loginWithGoogle();
                                        if (!mounted) return;
                                        if (success) {
                                          context.go('/feed');
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                        side: const BorderSide(color: Color(0xFFE2E2E2)),
                                      ),
                                      icon: const Icon(Icons.facebook, size: 18, color: Color(0xFF2B2B2B)),
                                      label: const Text(
                                        'Facebook',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2B2B2B)),
                                      ),
                                      onPressed: () async {
                                        final success = await ref.read(authProvider.notifier).loginWithFacebook();
                                        if (!mounted) return;
                                        if (success) {
                                          context.go('/feed');
                                        }
                                      },
                                    ),
                                  ),
                                ],
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
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newPwCtrl.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _otpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification code sent to your phone! (PIN: 1234)', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onResetPassword() {
    if (_codeCtrl.text.trim() != '1234' && _codeCtrl.text.trim() != '0000') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code. Use PIN: 1234', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_newPwCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset successfully! You can now sign in.', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          const Text(
            'Enter your registered phone number to receive a secure OTP code.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
          ),
          const SizedBox(height: 20),
          if (!_otpSent) ...[
            CustomInputField(
              controller: _phoneCtrl,
              hint: 'Phone Number (e.g. 01711000000)',
              prefixIcon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Send OTP Code',
              icon: Icons.sms_outlined,
              onPressed: _onSendOtp,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.tertiary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🔑 Demo PIN: 1234',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.tertiary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            CustomInputField(
              controller: _codeCtrl,
              hint: 'Enter 4-Digit OTP Code',
              prefixIcon: Icons.lock_clock_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            CustomInputField(
              controller: _newPwCtrl,
              hint: 'Enter New Password',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Update Password',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _onResetPassword,
            ),
          ],
        ],
      ),
    );
  }
}


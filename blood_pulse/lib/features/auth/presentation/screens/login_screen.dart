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
import '../../../../core/widgets/language_toggle_button.dart';
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
  bool _isGoogleSigningIn = false;
  String? _loginErrorMessage;

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
      context.go('/feed');
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Login failed.';
      final isCredentialFailure = err.toLowerCase().contains('credential') ||
          err.toLowerCase().contains('no active account') ||
          err.toLowerCase().contains('401') ||
          err.toLowerCase().contains('invalid');
      final errMsg = isCredentialFailure
          ? 'Invalid credentials. Please check your phone number/username or password.'
          : err;
      setState(() => _loginErrorMessage = errMsg);
      final bottomMargin = MediaQuery.of(context).viewInsets.bottom + 84.0;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
          content: Text(
            errMsg,
            style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w500),
          ),
          action: isCredentialFailure
              ? SnackBarAction(
                  label: 'Reset',
                  textColor: Colors.white,
                  onPressed: () => context.push('/forgot-password'),
                )
              : null,
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isGoogleSigningIn || ref.read(authProvider).isLoading) return;
    setState(() {
      _isGoogleSigningIn = true;
      _loginErrorMessage = null;
    });
    _idFocus.unfocus();
    _pwFocus.unfocus();

    try {
      final success = await ref.read(authProvider.notifier).signInWithGoogle();

      if (!mounted) return;
      if (success) {
        context.go('/feed');
      } else {
        final err = ref.read(authProvider).errorMessage;
        if (err != null && err.isNotEmpty) {
          final l10n = AppLocalizations.of(context);
          String displayErr = err;
          if (err.contains('cancelled') || err.contains('canceled')) {
            displayErr = l10n?.googleSignInCancelled ?? err;
          } else if (err.contains('Network') || err.contains('network_error') || err.contains('SocketException')) {
            displayErr = l10n?.networkError ?? err;
          } else if (err.contains('email is not verified')) {
            displayErr = l10n?.googleEmailNotVerified ?? err;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayErr, style: const TextStyle(fontFamily: 'Inter')),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: const StadiumBorder(),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSigningIn = false);
      }
    }
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
                        Align(
                          alignment: Alignment.topRight,
                          child: const LanguageToggleButton(),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 18),
                        // ── Card ──────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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

                              const SizedBox(height: 16),
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
                                  onTap: () => context.push('/forgot-password'),
                                  child: Text(
                                    l10n?.forgotPassword ?? 'Forgot password?',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.tertiary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // ── Divider with "or" ────────────────────────
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Color(0xFFE2E2E2), thickness: 1)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Color(0xFFE2E2E2), thickness: 1)),
                                ],
                              ),
                              const SizedBox(height: 18),
                              // ── Continue with Google ─────────────────────
                              CapsuleButton(
                                label: l10n?.continueWithGoogle ?? 'Continue with Google',
                                leading: Image.asset(
                                  'assets/images/google_logo.png',
                                  width: 20,
                                  height: 20,
                                ),
                                backgroundColor: const Color(0xFFFDEAEB),
                                foregroundColor: AppColors.secondary,
                                isLoading: _isGoogleSigningIn,
                                height: 50,
                                onPressed: (_isGoogleSigningIn || auth.isLoading) ? null : _onGoogleSignIn,
                              ),
                              const SizedBox(height: 12),
                              // ── Continue as Guest ────────────────────────
                              CapsuleButton(
                                label: l10n?.continueAsGuest ?? 'Continue as Guest',
                                icon: Icons.person_outline_rounded,
                                backgroundColor: const Color(0xFFFDEAEB),
                                foregroundColor: AppColors.secondary,
                                height: 50,
                                onPressed: () {
                                  ref.read(authProvider.notifier).continueAsGuest();
                                  context.go('/guest-welcome');
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_loginErrorMessage != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.error.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _loginErrorMessage!,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              // ── Sign In Button ──────────────────────────
                              CapsuleButton(
                                label: l10n?.signIn ?? 'Sign In',
                                icon: Icons.arrow_forward_rounded,
                                isLoading: auth.isLoading,
                                showGlow: true,
                                height: 50,
                                onPressed: auth.isLoading ? null : _onSignIn,
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // ── Register link ──────────────────────────────────
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                        SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom),
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



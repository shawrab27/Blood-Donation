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
                                  onTap: () => context.push('/forgot-password'),
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



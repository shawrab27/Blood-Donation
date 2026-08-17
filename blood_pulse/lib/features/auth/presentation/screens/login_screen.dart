import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/app_logo_slot.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F3),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // ── Logo ──────────────────────────────────────────
                      const AppLogoSlot(size: AppLogoSize.card),

                      const SizedBox(height: 20),

                      // ── Title ─────────────────────────────────────────
                      const Text(
                        'Blood Pulse',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Welcome back to the community.\nYour donation matters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                            _SectionLabel('Username or Phone'),
                            const SizedBox(height: 8),
                            CustomInputField(
                              controller: _idCtrl,
                              focusNode: _idFocus,
                              hint: 'Enter your credentials',
                              prefixIcon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).requestFocus(_pwFocus),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Please enter your username or phone'
                                  : null,
                            ),

                            const SizedBox(height: 20),

                            // ── Password ────────────────────────────────
                            _SectionLabel('Password'),
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
                                  return 'Password is required';
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
                                onTap: () {
                                  // TODO(phase-5): JIT OTP reset flow
                                },
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
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
                              label: 'Sign In',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: auth.isLoading,
                              showGlow: true,
                              onPressed: auth.isLoading ? null : _onSignIn,
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
                            "Don't have an account? ",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: AppColors.neutral,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: const Text(
                              'Create an Account',
                              style: TextStyle(
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

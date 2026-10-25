// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// Modal bottom sheet: "Complete your account to continue"
/// Displays a soft-wall barrier for guests and incomplete logged-in users.
class RegistrationGatePopup extends ConsumerWidget {
  final bool isGuest;
  final String? targetRoute;

  const RegistrationGatePopup({
    super.key,
    required this.isGuest,
    this.targetRoute,
  });

  static bool _isShowing = false;

  /// Displays the modal bottom sheet. Dismissing stays on the current screen.
  /// Debounced: does nothing if a registration gate popup is already active.
  static Future<void> show(
    BuildContext context, {
    required bool isGuest,
    String? targetRoute,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => RegistrationGatePopup(
          isGuest: isGuest,
          targetRoute: targetRoute,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomPadding),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Red shield / lock badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF9CDD2), width: 1.2),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title: "Complete your account to continue"
            const Text(
              'Complete your account to continue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            const Text(
              'Declare your blood group and details to react, comment, post, or request blood.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Complete Registration / Register Now Capsule Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PressableScale(child: ElevatedButton(
                key: const Key('registration_gate_button'),
                onPressed: () {
                  Navigator.of(context).pop();
                  final auth = ref.read(authProvider);
                  final u = auth.user;
                  final isGoogle = u?.authProvider == 'google' ||
                      (u != null && u.email.isNotEmpty && u.authProvider != 'credentials');
                  context.push(
                    '/register',
                    extra: {
                      if (targetRoute != null) 'targetRoute': targetRoute,
                      'prefillName': u?.fullName ?? '',
                      'prefillEmail': u?.email ?? '',
                      'isGoogleUser': isGoogle,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isGuest ? 'Register Now' : 'Complete Registration',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              )),
            ),
            const SizedBox(height: 12),

            // Already have an account? Log in Link
            if (isGuest)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/login');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text(
                        'Log in',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

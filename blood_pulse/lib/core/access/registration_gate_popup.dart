// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'profile_completion_modal.dart';

/// Stitch "Complete your registration" modal dialog.
/// Displays a soft-wall barrier for guests and incomplete logged-in users.
class RegistrationGatePopup extends StatelessWidget {
  final bool isGuest;
  final String? targetRoute;

  const RegistrationGatePopup({
    super.key,
    required this.isGuest,
    this.targetRoute,
  });

  static bool _isShowing = false;

  /// Displays the modal dialog. Dismissing via X stays on the current screen.
  /// Debounced: does nothing if a registration gate popup is already currently active.
  static Future<void> show(BuildContext context, {required bool isGuest, String? targetRoute}) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => RegistrationGatePopup(isGuest: isGuest, targetRoute: targetRoute),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Close Button
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF555555), size: 18),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Red/Pink Shield Lock Icon Badge (Stitch 2acc8f8bc1e9476a81976c9537c4842b)
            SizedBox(
              width: 78,
              height: 78,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E8),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF9CDD2), width: 1.2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // English & Bangla Title
            const Text(
              'Complete your registration',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'রেজিস্ট্রেশন সম্পূর্ণ করুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            const Text(
              'to explore all features\nসব ফিচার দেখতে রেজিস্ট্রেশন সম্পন্ন করুন',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Register Now / Complete Profile Capsule Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (isGuest) {
                    context.push('/register', extra: targetRoute != null ? {'targetRoute': targetRoute} : null);
                  } else {
                    ProfileCompletionModal.show(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        isGuest ? 'Register Now / রেজিস্ট্রেশন করুন' : 'Complete Profile / প্রোফাইল সম্পূর্ণ করুন',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Already have an account? Log in Link
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
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/login');
                  },
                  child: const Text(
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
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
}
}

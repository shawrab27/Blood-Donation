// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/presentation/providers/auth_notifier.dart';

/// Stitch Screen 8: Logout Confirmation Modal Sheet / Dialog.
/// Features clean circular logout badge, warning text, dual pill actions,
/// and "Verified Safe Session" security status.
class LogoutConfirmationModal extends StatelessWidget {
  final VoidCallback? onConfirm;

  const LogoutConfirmationModal({super.key, this.onConfirm});

  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LogoutConfirmationModal(
        onConfirm: () {
          Navigator.of(ctx).pop();
          ref.read(authProvider.notifier).logout();
          context.go('/login');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close X Button
            Align(
              alignment: Alignment.topRight,
              child: PressableScale(child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )),
            ),

            // Red Icon Circle (Double layer soft red)
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFFFECEE),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDAD7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFC30121), size: 24),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Logout',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF24191A),
              ),
            ),
            const SizedBox(height: 10),

            // Prompt Question
            const Text(
              'Are you sure you want to logout?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF24191A),
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle Description
            const Text(
              'You can sign back in anytime to respond to urgent blood donation alerts in your neighborhood.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF5C3F3D),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Dual Capsule Action Buttons
            Row(
              children: [
                Expanded(
                  child: PressableScale(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDEAEB),
                      foregroundColor: const Color(0xFF24191A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PressableScale(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0015),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: onConfirm,
                    child: const Text(
                      'Logout',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Safe Session Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shield_outlined, size: 13.5, color: Color(0xFF8E7D7F)),
                SizedBox(width: 5),
                Text(
                  'VitalFlow Safe Session',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: Color(0xFF8E7D7F),
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

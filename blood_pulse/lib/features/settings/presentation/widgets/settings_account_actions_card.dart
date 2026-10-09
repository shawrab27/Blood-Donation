// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../profile/presentation/widgets/modals/delete_account_confirmation_modal.dart';
import '../../../profile/presentation/widgets/modals/logout_confirmation_modal.dart';

/// Account & Danger Actions Card in Settings matching Stitch Screen 5:
/// Create New Account, Delete Account, and Logout.
class SettingsAccountActionsCard extends ConsumerWidget {
  const SettingsAccountActionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Create New Account
          _buildActionTile(
            icon: Icons.person_add_rounded,
            iconBgColor: const Color(0xFFF8E3E5),
            iconColor: AppColors.primary,
            title: 'Create New Account',
            subtitle: 'Register another donor profile or organization',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Create New Account', style: TextStyle(fontFamily: 'Georgia')),
                  content: const Text('Do you want to log out of this account and register a new donor or organization account?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(authProvider.notifier).logout();
                        context.go('/register');
                      },
                      child: const Text('Register New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // Delete Account (Stitch Screen 7)
          _buildActionTile(
            icon: Icons.delete_outline_rounded,
            iconBgColor: const Color(0xFFFFDAD6),
            iconColor: const Color(0xFFBA1A1A),
            title: 'Delete Account',
            titleColor: const Color(0xFFBA1A1A),
            subtitle: null,
            onTap: () => DeleteAccountConfirmationModal.show(context),
          ),
          const Divider(height: 1, indent: 56, color: Color(0xFFF8E3E5)),

          // Logout (Stitch Screen 8)
          _buildActionTile(
            icon: Icons.logout_rounded,
            iconBgColor: const Color(0xFFF8E3E5),
            iconColor: AppColors.primary,
            title: 'Logout',
            subtitle: null,
            onTap: () => LogoutConfirmationModal.show(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    Color? titleColor,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF24191A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF5C3F3D),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF916F6C)),
          ],
        ),
      ),
    );
  }
}

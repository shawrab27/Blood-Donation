import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/presentation/providers/auth_notifier.dart';
import '../../../domain/providers/profile_provider.dart';

/// Stitch Screen 7: Delete Account Confirmation Modal Sheet / Dialog.
/// Features danger alert badge, donor impact summary card (Donations, Lives Saved, Blood Pool),
/// and irreversible permanent soft-deletion confirmation.
class DeleteAccountConfirmationModal extends ConsumerStatefulWidget {
  const DeleteAccountConfirmationModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const DeleteAccountConfirmationModal(),
    );
  }

  @override
  ConsumerState<DeleteAccountConfirmationModal> createState() =>
      _DeleteAccountConfirmationModalState();
}

class _DeleteAccountConfirmationModalState
    extends ConsumerState<DeleteAccountConfirmationModal> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await ref.read(authProvider.notifier).deleteAccount(
      onError: (error) {
        if (mounted) {
          setState(() => _isDeleting = false);
          messenger.showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (success && mounted) {
      navigator.pop();
      context.go('/login');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Account permanently deleted and data anonymized.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final profileAsync = ref.watch(profileProvider);

    int donations = authUser?.totalBagsDonated ?? 0;
    profileAsync.whenData((p) {
      if (p != null && p.totalBagsDonated > 0) {
        donations = p.totalBagsDonated;
      }
    });

    final int livesSaved = donations * 3;
    const String bloodPool = '0+';

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
              child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            // Danger Trash Icon Circle
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDAD6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFBA1A1A), size: 30),
            ),
            const SizedBox(height: 14),

            // Title
            const Text(
              'Delete Account?',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFBA1A1A),
              ),
            ),
            const SizedBox(height: 8),

            // Warning Subtitle
            const Text(
              'Are you sure you want to delete your account? All your donation records, saved certificates, and donor rankings will be permanently erased. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF5C3F3D),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Donor Impact Summary Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildImpactMetric('$donations', 'Donations'),
                  Container(width: 1, height: 28, color: const Color(0xFFE6BDBA)),
                  _buildImpactMetric('$livesSaved', 'Lives Saved'),
                  Container(width: 1, height: 28, color: const Color(0xFFE6BDBA)),
                  _buildImpactMetric(bloodPool, 'Blood Pool'),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Dual Capsule Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF24191A),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBA1A1A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isDeleting ? null : _handleDelete,
                    child: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: AppLoader(),
                          )
                        : const Text(
                            'Yes, Delete',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildImpactMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFBA1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF5C3F3D),
          ),
        ),
      ],
    );
  }
}

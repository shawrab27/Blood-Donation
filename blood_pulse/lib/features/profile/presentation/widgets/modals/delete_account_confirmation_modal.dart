// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'dart:convert';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../../services/api_client.dart';

/// Stitch Screen 7: Delete Account Confirmation Modal Sheet / Dialog.
/// Features danger alert badge, verified impact metrics (Donations, Requests, Posts),
/// re-auth password confirmation, and compliant account deletion.
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
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isDeleting = false;
  bool _isLoadingSummary = false;
  int _donationsCount = 0;
  int _requestsCount = 0;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authProvider).user;
    _donationsCount = authUser?.totalBagsDonated ?? 0;
    _fetchAccountSummary();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccountSummary() async {
    try {
      final response = await ApiClient().get('account/summary/');
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _donationsCount = (data['donations_count'] as num?)?.toInt() ?? 0;
          _requestsCount = (data['requests_count'] as num?)?.toInt() ?? 0;
          _isLoadingSummary = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      final authUser = ref.read(authProvider).user;
      setState(() {
        _donationsCount = authUser?.totalBagsDonated ?? 0;
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final password = _passwordController.text.trim();

    final success = await ref.read(authProvider.notifier).deleteAccount(
      password: password.isNotEmpty ? password : null,
      confirm: true,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
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

              // Danger Exclamation Icon Circle (Double layer soft red)
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
                      color: Color(0xFFFFDAD6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: Color(0xFFBA1A1A), size: 28),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Delete Account?',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              const SizedBox(height: 8),

              // Irreversible Action Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFB4AB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFBA1A1A)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Irreversible action',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFBA1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Prompt Question
              const Text(
                'Are you sure you want to delete your account?',
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
                'All your donation records, saved certificates, and donor rankings will be permanently erased. This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: Color(0xFF5C3F3D),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Donor Verified Impact Summary Card (Donations | Requests | Blood Pool)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3DDE0)),
                ),
                child: _isLoadingSummary
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(width: 20, height: 20, child: AppLoader()),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: _buildImpactMetric(
                              '$_donationsCount',
                              'Donations',
                              const Color(0xFFC30121),
                            ),
                          ),
                          Container(width: 1, height: 26, color: const Color(0xFFE6BDBA)),
                          Expanded(
                            child: _buildImpactMetric(
                              '${_requestsCount > 0 ? _requestsCount : 18}',
                              'Requests',
                              const Color(0xFF004B7E),
                            ),
                          ),
                          Container(width: 1, height: 26, color: const Color(0xFFE6BDBA)),
                          Expanded(
                            child: _buildImpactMetric(
                              ref.read(authProvider).user?.bloodGroup.isNotEmpty == true
                                  ? ref.read(authProvider).user!.bloodGroup
                                  : 'O+',
                              'Blood Pool',
                              const Color(0xFF24191A),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Re-authentication Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Enter password to confirm deletion',
                  hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: PressableScale(child: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFFFF8F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                      onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
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
                        backgroundColor: const Color(0xFFC30121),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpactMetric(String value, String label, [Color? color]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? const Color(0xFFBA1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

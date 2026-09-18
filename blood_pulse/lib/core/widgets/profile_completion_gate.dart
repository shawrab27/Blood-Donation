import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

/// Wraps any screen or tab with a frosted blur lock gate if the user's
/// profile is incomplete (e.g. Google Sign-In or guest without blood group/district).
class ProfileCompletionGate extends ConsumerWidget {
  const ProfileCompletionGate({
    super.key,
    required this.child,
    this.featureName = 'this feature',
  });

  final Widget child;
  final String featureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isComplete = user != null && user.isProfileComplete;

    if (isComplete) {
      return child;
    }

    return Stack(
      children: [
        // Blurry backdrop behind the lock
        AbsorbPointer(
          absorbing: true,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Opacity(
              opacity: 0.35,
              child: child,
            ),
          ),
        ),

        // Centered Frosted Lock Card
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(245),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withAlpha(45), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(25),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withAlpha(40), width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_person_rounded,
                        color: AppColors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'To unlock , donor contacts, and emergency requests, please declare your blood group, phone number, and district.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  // Missing Fields Indicators
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildPill(
                        'Blood Group',
                        user?.bloodGroup.isNotEmpty == true,
                      ),
                      _buildPill(
                        'District / City',
                        user?.categoryDetails['district']?.isNotEmpty == true,
                      ),
                      _buildPill(
                        'Phone Number',
                        user?.primaryPhone.isNotEmpty == true &&
                            !user!.primaryPhone.startsWith('+8800000'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),

                  // Capsule Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/complete-profile');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Complete Registration',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String label, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFE8F7EE) : const Color(0xFFFFF2F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? const Color(0xFF1B8A4E).withAlpha(80) : AppColors.primary.withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: isDone ? const Color(0xFF1B8A4E) : AppColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDone ? const Color(0xFF1B8A4E) : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

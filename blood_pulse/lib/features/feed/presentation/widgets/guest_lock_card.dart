// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/access/registration_gate_popup.dart';

/// Card displayed on the Guest Home feed locking "Blood Hub, Chat & Profile".
class GuestLockCard extends ConsumerWidget {
  const GuestLockCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF7CCD3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC30121).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => RegistrationGatePopup.show(context, isGuest: true),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Blood Hub, Chat & Profile',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF999999),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Complete your registration to see all features\nসব ফিচার দেখতে রেজিস্ট্রেশন সম্পূর্ণ করুন',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Register now button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => RegistrationGatePopup.show(context, isGuest: true),
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
                  Flexible(
                    child: Text(
                      'Register now / রেজিস্ট্রেশন করুন',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Log in link
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/login'),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// PulseAI quick card displayed in guest mode. Pressing "Try PulseAI" opens the popup.
class GuestPulseAICard extends StatelessWidget {
  const GuestPulseAICard({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/assistant'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0E5E5), width: 1.2),
        ),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/pulseai_icon.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                cacheWidth: 76,
                cacheHeight: 76,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'PulseAI',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ask about donation, eligibility and health',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: Color(0xFF777777),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => context.push('/assistant'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6D6D6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: const Text(
                'Try PulseAI',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

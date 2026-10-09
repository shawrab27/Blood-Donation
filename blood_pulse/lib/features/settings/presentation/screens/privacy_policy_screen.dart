// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/core/widgets/custom_app_bar.dart';
import 'package:blood_pulse/core/widgets/responsive_center_wrapper.dart';
import '../widgets/privacy_dpo_card.dart';

/// Stitch Screen 6: Privacy Policy Screen
/// 1:1 Parity: Trust Banner, 6 Governance Clauses, copyable DPO email chip, and AES-256 footer.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  static const _clauses = [
    (
      'Clinical Parameters & Donation Records',
      'Collection of verified blood groupings, hemoglobin ranges, antigen profiles, and historical intervals to confirm biological compatibility before dispatch.',
    ),
    (
      'End-to-End Cryptographic Masking',
      'Personal contact telephone numbers and identities undergo continuous multi-layer encryption. Direct identity remains obfuscated during transit until formal bed-side verification.',
    ),
    (
      'Certified Hospital Partners & Zero Ad Sales',
      'Access is strictly restricted to vetted medical networks and licensed blood centers. Donor records are never sold, rented, or repurposed for marketing aggregates.',
    ),
    (
      'Geofenced Radius Privacy',
      'Precise GPS coordinates are deliberately coarsened within a 2.5-kilometer general radius. High-resolution routing is only rendered once an emergency dispatch request is accepted.',
    ),
    (
      'Right to Portability & Erasure',
      'Donors preserve total sovereignty over biological profiles. You may export verified records or request complete erasure of non-statutory identifying factors within 48 hours.',
    ),
    (
      'Data Security Incidents',
      'In the event of any security incident, all impacted users will be proactively notified within 72 hours alongside comprehensive incident mitigation steps.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: CustomAppBar(
        showLogo: true,
        showBackButton: true,
        showNotification: true,
        showProfile: true,
        onBack: () => context.canPop() ? context.pop() : context.go('/settings'),
      ),
      body: ResponsiveCenterWrapper(
        maxWidth: 540,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Trust Banner
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CLINICAL INTEGRITY',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your Data Protects Lives',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We safeguard every donor record with medical-grade precision.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF5C3F3D)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: Color(0xFFFEE9EB), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Metadata Row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(Icons.schedule_rounded, 'Last Update • 20 June 2024', const Color(0xFFF8E3E5), AppColors.primary),
                _buildChip(Icons.verified_user_rounded, 'HIPAA & GDPR', Colors.white, const Color(0xFF004B7E), hasBorder: true),
              ],
            ),
            const SizedBox(height: 14),

            // Commitment Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.health_and_safety_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Donor Trust Commitment',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'BloodPulse is built on an unwavering commitment to clinical privacy, medical ethics, and personal confidentiality. In adherence to international transfusion standards, HIPAA guidelines, and GDPR mandates, every piece of donor health history, biological metric, and emergency contact record is cryptographically secured with zero commercial monetization.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF24191A), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Core Governance Protocols Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  child: Text(
                    'Core Governance Protocols',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Text('6 Clauses', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 10),

            // 6 Governance Clauses
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF3DDE0)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _clauses.length; i++) ...[
                    if (i > 0) const Divider(height: 20, color: Color(0xFFF3DDE0)),
                    _buildClause(_clauses[i].$1, _clauses[i].$2),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Copyable Data Protection Officer Chip
            const PrivacyDpoCard(),
            const SizedBox(height: 18),

            // AES-256 Footer
            Center(
              child: Text(
                '🔒 Cryptographically Secured & Verified Transfusion Privacy Policy • BloodPulse Medical Network',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color bgColor, Color textColor, {bool hasBorder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(50),
        border: hasBorder ? Border.all(color: const Color(0xFFE2E8F0)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildClause(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
              ),
              const SizedBox(height: 3),
              Text(desc, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5C3F3D), height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}

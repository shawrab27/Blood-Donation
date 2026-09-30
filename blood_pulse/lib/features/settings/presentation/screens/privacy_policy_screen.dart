// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7), // bg-surface
      appBar: AppBar(
        backgroundColor: const Color(0xCCFFF8F7),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF24191A)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDAD7), // primary-fixed
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.monitor_heart_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'BloodPulse',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                ),
                Text(
                  'Privacy Policy',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5C3F3D)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trust Banner
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1), // surface-container-low
                borderRadius: BorderRadius.circular(16),
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
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.8),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your Data Protects Lives',
                          style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We safeguard every donor record with medical-grade precision.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF5C3F3D)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBaKWgkvT8bxo7WWidxYXxBP0iQqTkuZiPScW2gb-n88bwltsAAlAhDN9ImssppYXNsD5mCjNuQhRe_Ghw5UXfSxxZgWcp38jRaFvOvHRKKmKEzI4pl4HxlHO8WU3u-TyuTL8ISzAs1gw2WmBt6aJqZOmyciOilS-JRs5Muldb7_K7m5DGoK7h6qvx876D_n6F3MT2tWLOcWpaFF7DGzeuv0yaufx5uy_YxqXQJVIk',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_,_,_) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Metadata
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8E3E5), // surface-container-high
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Last Update \u2022 20 June 2024', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C3F3D))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF004B7E)),
                      SizedBox(width: 6),
                      Text('HIPAA & GDPR', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF004B7E))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Commitment
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.shield_rounded, size: 20, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Donor Trust Commitment', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BloodPulse is built on an unwavering commitment to clinical privacy, medical ethics, and personal confidentiality. In adherence to international transfusion standards, HIPAA guidelines, and GDPR mandates, every piece of donor health history, biological metric, and emergency contact record is cryptographically secured with zero commercial monetization.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF24191A), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Interactive Policy Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Core Governance Protocols', style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF24191A))),
                Text('6 Clauses', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Clauses
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: Column(
                children: [
                  _buildClause('Clinical Parameters & Donation Records', 'Collection of verified blood groupings, hemoglobin ranges, antigen profiles, and comprehensive historical donation intervals to confirm physical readiness and biological compatibility before dispatch.'),
                  const SizedBox(height: 24),
                  _buildClause('End-to-End Cryptographic Masking', 'Personal contact telephone numbers and legal identities undergo continuous multi-layer encryption. Direct identity remains obfuscated during transit until an authorized healthcare professional initiates formal bed-side verification.'),
                  const SizedBox(height: 24),
                  _buildClause('Certified Hospital Partners & Zero Ad Sales', 'Access is strictly restricted to vetted medical networks and licensed blood centers. We strictly maintain a lifetime non-monetization policy: donor records are never sold, rented, or repurposed for marketing aggregates.'),
                  const SizedBox(height: 24),
                  _buildClause('Geofenced Radius Privacy', 'Precise GPS coordinates are deliberately coarsened within a 2.5-kilometer general radius. High-resolution routing is only rendered once a donor intentionally confirms acceptance of an immediate emergency dispatch request.'),
                  const SizedBox(height: 24),
                  _buildClause('Right to Portability & Erasure', 'Donors preserve total sovereignty over their biological profiles. You may export your verified hematology history at any moment or request complete erasure of all non-statutory identifying factors within 48 hours.'),
                  const SizedBox(height: 24),
                  _buildClause('Data Security Incidents', 'In the event of a breach, all impacted users will be notified within 72 hours alongside comprehensive incident response procedures.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClause(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFC30121).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFC30121),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24191A))),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF5C3F3D), height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

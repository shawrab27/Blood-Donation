// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../data/blood_hub_api_service.dart';

/// Donor result card matching Stitch "donor_search_enhanced_filters" layout.
class DonorCard extends StatelessWidget {
  const DonorCard({
    super.key,
    required this.donor,
    required this.onRequestTap,
  });

  final DonorSearchModel donor;
  final VoidCallback onRequestTap;

  @override
  Widget build(BuildContext context) {
    final locationText = donor.campus != null && donor.campus!.isNotEmpty
        ? donor.campus!
        : (donor.district.isNotEmpty ? '${donor.district}, ${donor.division}' : donor.division);

    final lastDonation = donor.lastDonationDays != null
        ? '${(donor.lastDonationDays! / 30).floor()} months ago'
        : (donor.isEligible ? 'Eligible now' : 'Recent donor');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name + Blood Group
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            donor.name,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF24191A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (donor.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Color(0xFFC30121),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          donor.campus != null && donor.campus!.isNotEmpty
                              ? Icons.school_outlined
                              : Icons.location_on_outlined,
                          size: 15,
                          color: const Color(0xFF5C3F3D),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF5C3F3D),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  donor.bloodGroup,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Middle Box: Last Donation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3DDE0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: Color(0xFF916F6C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Donation',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF916F6C),
                        ),
                      ),
                      Text(
                        lastDonation,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF24191A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: donor.isEligible
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    donor.isEligible ? 'Eligible' : 'Cooling Down',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: donor.isEligible
                          ? const Color(0xFF1B8A4E)
                          : const Color(0xFF757575),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Request Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRequestTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text(
                'Request',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

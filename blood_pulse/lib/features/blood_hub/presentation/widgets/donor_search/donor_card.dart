// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../data/blood_hub_api_service.dart';

/// Donor result card matching Stitch UI specification.
/// Features verified badge, campus location, blood group pill, last donation box,
/// and an interactive direct requisition popup card when "Request" is tapped.
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
    final districtText = donor.district.isNotEmpty ? donor.district : 'Bangladesh';
    final tierBadge = donor.badge;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3DDE0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x088E7D7F),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Donor Name + District on left, Blood Group Pill on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF5C3F3D),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            districtText,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFE6BDBA), width: 0.8),
                ),
                child: Text(
                  donor.bloodGroup,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF960017),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Platform Tier Badge Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3DDE0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.military_tech_rounded,
                  size: 16,
                  color: Color(0xFFC30121),
                ),
                const SizedBox(width: 6),
                Text(
                  tierBadge,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF24191A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Request Button: Capsule Shape with Interactive Popup
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showDonorRequestCard(context),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Donor Requisition Popup Card
  void _showDonorRequestCard(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0D5D5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      donor.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
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
                          color: Color(0xFF960017),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${donor.district.isNotEmpty ? donor.district : 'Bangladesh'} • ${donor.badge}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF5F5E5E),
                  ),
                ),
                const SizedBox(height: 16),

                // Compatibility banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF3DDE0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1B8A4E), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Direct requisition will send priority push notification and wave dispatch to this donor.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF24191A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5F5E5E),
                          side: const BorderSide(color: Color(0xFFE8DADA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onRequestTap();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC30121),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Send Request',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

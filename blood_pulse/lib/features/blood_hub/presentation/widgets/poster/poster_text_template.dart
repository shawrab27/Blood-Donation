// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'poster_common_components.dart';

/// Template 2: Clean Alert (High Contrast / Text-Only Design).
/// Aligned with Stitch Screen: BloodPulse Emergency Social Media Posters (Clean Alert).
class PosterTextTemplate extends StatelessWidget {
  const PosterTextTemplate({
    super.key,
    required this.data,
    this.isBangla = false,
  });

  final PosterData data;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(70), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PosterBrandHeader(
            title: isBangla ? 'জরুরি রক্ত প্রয়োজন' : 'URGENT BLOOD NEEDED',
            subtitle: isBangla
                ? 'রোগীর ইনিশিয়াল: ${data.patientName}'
                : 'Emergency Dispatch • ${data.patientName}',
            backgroundColor: const Color(0xFFFFF8F7),
            titleColor: AppColors.primary,
            isBangla: isBangla,
          ),
          _buildHeroBloodSection(),
          _buildMetricsGrid(),
          _buildAttendantContactBar(),
          PosterBrandFooter(
            backgroundColor: AppColors.secondary,
            isBangla: isBangla,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBloodSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Text(
            '${isBangla ? "রোগী:" : "Patient:"} ${data.patientName} (${data.condition})',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: Colors.white, width: 4),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.bloodGroup,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${data.unitsNeeded} ${isBangla ? "ব্যাগ" : "Bag(s)"}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD1CD),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _metricCard(
              icon: Icons.local_hospital_outlined,
              label: isBangla ? 'হাসপাতাল / স্থান' : 'HOSPITAL / LOCATION',
              title: data.hospitalName ?? 'Emergency Care',
              subtitle: data.location,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricCard(
              icon: Icons.timelapse_rounded,
              label: isBangla ? 'প্রয়োজনের সময়' : 'TIMELINE',
              title: data.dateNeeded ?? (isBangla ? 'আজকের মধ্যে' : 'Today, Urgent'),
              subtitle: isBangla
                  ? 'জরুরি অবস্থা: ${data.urgencyLevel}'
                  : 'Urgency: ${data.urgencyLevel}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8E7D7F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendantContactBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded,
                color: Color(0xFF69F0AE), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBangla ? 'যোগাযোগ নম্বর' : 'Verified Attendant',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8.5,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    data.contactNumber ?? '+880 1700-000000',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                isBangla ? 'কল করুন' : 'Call Now',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

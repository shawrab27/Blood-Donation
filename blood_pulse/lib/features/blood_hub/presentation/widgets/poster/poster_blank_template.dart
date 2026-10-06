// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';

/// Template 3: Story Alert (Full-Bleed Crimson Gradient / Blank Customizable).
/// Aligned with Stitch Screen: BloodPulse Emergency Social Media Posters.
class PosterBlankTemplate extends StatelessWidget {
  const PosterBlankTemplate({
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC30121), Color(0xFF6B000E), Color(0xFF1A0306)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withAlpha(90), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStoryTopHeader(),
          _buildHeadlineSection(),
          _buildBloodGroupHero(),
          _buildCustomMessageCard(),
          _buildBottomContactAction(),
        ],
      ),
    );
  }

  Widget _buildStoryTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(40))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset('assets/images/Blood Pulse logo.jpg', width: 26, height: 26, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.water_drop, color: Colors.white, size: 20)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBangla ? 'ব্লাডপালস • জরুরি' : 'BloodPulse • Emergency',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF69F0AE), size: 12),
                const SizedBox(width: 4),
                Text(
                  isBangla ? 'ভেরিফাইড' : 'Verified',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadlineSection() {
    final headline = data.customHeadline?.isNotEmpty == true
        ? data.customHeadline!
        : (isBangla ? 'জরুরি রক্ত প্রয়োজন' : 'URGENT BLOOD NEEDED');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(100),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Text(
              isBangla
                  ? 'জরুরি অবস্থা: ${data.urgencyLevel}'
                  : 'URGENCY: ${data.urgencyLevel}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFCDD2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: const Color(0xFFFFCDD2), width: 3),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data.bloodGroup,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: AppColors.primary,
              ),
            ),
            Text(
              '${data.unitsNeeded} ${isBangla ? "ব্যাগ" : "Bag(s)"}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMessageCard() {
    final message = data.customMessage?.isNotEmpty == true
        ? data.customMessage!
        : (isBangla
            ? '${data.patientName}-এর জন্য জরুরি রক্তের প্রয়োজন। স্থান: ${data.location}।'
            : 'Blood needed for ${data.patientName}. Location: ${data.location}.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${isBangla ? "হাসপাতাল:" : "Hospital:"} ${data.hospitalName ?? data.location}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFCDD2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomContactAction() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      data.contactNumber ?? '+880 1700-000000',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                  ],
                ),
                Text(
                  isBangla ? 'জরুরি কল' : 'Call Now',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'bloodpulse.app • You give today, They live today',
            style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

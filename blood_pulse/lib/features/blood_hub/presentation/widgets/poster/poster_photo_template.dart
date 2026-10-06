// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'poster_common_components.dart';

/// Template 1: Patient Photo + Text (Urgent Red Design).
/// Aligned with Stitch Screen: BloodPulse Emergency Social Media Posters (Full Story).
class PosterPhotoTemplate extends StatelessWidget {
  const PosterPhotoTemplate({
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
        border: Border.all(color: AppColors.primary.withAlpha(50), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
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
                ? 'তাৎক্ষণিক রক্তদাতা আবশ্যক'
                : 'Immediate Donor Dispatch',
            isBangla: isBangla,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 5, child: _buildPatientPhotoBox()),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: _buildBloodBadgeCard()),
                  ],
                ),
                const SizedBox(height: 12),
                _buildClinicalInfoCard(),
              ],
            ),
          ),
          PosterBrandFooter(isBangla: isBangla),
        ],
      ),
    );
  }

  Widget _buildPatientPhotoBox() {
    Widget imageWidget;
    if (data.photoBytes != null) {
      imageWidget = Image.memory(
        data.photoBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 110,
      );
    } else if (data.photoPath != null && data.photoPath!.isNotEmpty) {
      imageWidget = Image.file(
        File(data.photoPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 110,
        errorBuilder: (_, _, _) => _photoFallback(),
      );
    } else {
      imageWidget = _photoFallback();
    }

    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              color: Colors.black.withAlpha(180),
              child: Text(
                data.patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoFallback() {
    return Container(
      color: const Color(0xFFFEE9EB),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline_rounded,
              size: 38, color: AppColors.primary),
          const SizedBox(height: 2),
          Text(
            isBangla ? 'রোগীর ছবি' : 'Patient Photo',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodBadgeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  data.bloodGroup,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.unitsNeeded} ${isBangla ? 'ব্যাগ রক্ত' : 'Bag(s)'}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      data.urgencyLevel,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              isBangla ? 'হোল ব্লাড / রক্তের উপাদান' : 'Whole Blood Required',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        children: [
          PosterInfoRow(
            icon: Icons.local_hospital_rounded,
            iconColor: AppColors.primary,
            label: isBangla ? 'হাসপাতাল:' : 'Hospital:',
            value: data.hospitalName ?? 'Hospital / Clinic',
          ),
          const Divider(height: 10, thickness: 0.5),
          PosterInfoRow(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.tertiary,
            label: isBangla ? 'অবস্থান:' : 'Location:',
            value: data.location,
          ),
          const Divider(height: 10, thickness: 0.5),
          PosterInfoRow(
            icon: Icons.phone_in_talk_rounded,
            iconColor: const Color(0xFF1B8A4E),
            label: isBangla ? 'যোগাযোগ:' : 'Contact:',
            value: data.contactNumber ?? '+880 1700-000000',
            isBold: true,
          ),
        ],
      ),
    );
  }
}

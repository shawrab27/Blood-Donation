// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../domain/models/community_models.dart';

class LocalClubProfileView extends StatelessWidget {
  const LocalClubProfileView({super.key, required this.club});
  final LocalClub club;

  @override
  Widget build(BuildContext context) {
    final hasEcMembers = club.executiveMembers.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        showBackButton: true,
        subtitle: club.name,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner Section ──────────────────────────────────────────
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 220),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                image: club.coverPhotoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(club.coverPhotoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withAlpha(190),
                      Colors.black.withAlpha(90),
                      Colors.black.withAlpha(220),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      club.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (club.slogan.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        club.slogan,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        CapsuleButton(
                          label: 'Donate Now',
                          height: 38,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Donation drive open for ${club.name}!'), backgroundColor: AppColors.primary),
                            );
                          },
                        ),
                        PressableScale(child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.black.withAlpha(70),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Requested to join ${club.name}!'), backgroundColor: AppColors.primary),
                            );
                          },
                          child: const Text(
                            'Join Club',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── About Us Section ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About Us',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    club.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: AppColors.neutral,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 2x2 Stats Grid ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.groups_rounded,
                      value: club.totalDonors.isNotEmpty ? club.totalDonors : '1.2k+',
                      label: 'Total Donors',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.water_drop_rounded,
                      value: club.activeDonors.isNotEmpty ? club.activeDonors : '850+',
                      label: 'Active Donors',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.volunteer_activism_rounded,
                      value: club.contributions.isNotEmpty ? club.contributions : '5k+',
                      label: 'Contributions',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_today_rounded,
                      value: club.establishedYear != null ? '${club.establishedYear}' : '2015',
                      label: 'Established',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Executive Committee Section ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Executive Committee',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Leadership team for the current session.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.neutral,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Featured President Card (Large circular photo with red border)
                  _FeaturedPresidentCard(
                    name: club.presidentName.isNotEmpty ? club.presidentName : 'Club President',
                    phone: club.contactNumber,
                  ),
                  const SizedBox(height: 16),

                  // Other EC Members
                  if (hasEcMembers)
                    ...club.executiveMembers.where((m) => !m.designation.toLowerCase().contains('president')).map((m) {
                      return _EcMemberRow(
                        name: m.name,
                        designation: m.designation,
                        phone: m.phoneNumber,
                      );
                    })
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No other executive committee members listed yet.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.neutral,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedPresidentCard extends StatelessWidget {
  const _FeaturedPresidentCard({required this.name, required this.phone});
  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Avatar with Red Ring
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
              color: const Color(0xFFF3DDE0),
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, size: 42, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FF),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text(
                  'Verified Club',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                ),
              ),
              const Text(
                'President',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            PressableScale(child: OutlinedButton.icon(
              icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFF1B8A4E)),
              label: Text(
                phone,
                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF1B8A4E)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1B8A4E)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () async {
                final uri = Uri.parse('tel:$phone');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contact $phone copied to clipboard.'), backgroundColor: AppColors.primary),
                      );
                    }
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Contact $phone copied to clipboard.'), backgroundColor: AppColors.primary),
                    );
                  }
                }
              },
            )),
          ],
        ],
      ),
    );
  }
}

class _EcMemberRow extends StatelessWidget {
  const _EcMemberRow({
    required this.name,
    required this.designation,
    this.phone = '',
  });
  final String name;
  final String designation;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF3DDE0),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  designation,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ),
          if (hasPhone)
            PressableScale(child: IconButton(
              icon: const Icon(Icons.phone_rounded, color: Color(0xFF1B8A4E), size: 20),
              onPressed: () async {
                final uri = Uri.parse('tel:$phone');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contact $phone copied to clipboard.'), backgroundColor: AppColors.primary),
                      );
                    }
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Contact $phone copied to clipboard.'), backgroundColor: AppColors.primary),
                    );
                  }
                }
              },
            )),
        ],
      ),
    );
  }
}

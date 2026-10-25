// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:blood_pulse/core/widgets/pressable_card.dart';
export 'package:blood_pulse/core/widgets/pressable_card.dart';


/// Primary action cards for Blood Hub Landing:
/// Segment 1: "Search for Donor"
/// Segment 2: "Emergency Blood" (Crimson gradient with interactive Emergency Dispatch popup card)
class LandingActionCards extends StatelessWidget {
  const LandingActionCards({
    super.key,
    required this.isBangla,
    required this.onSearchTap,
    required this.onEmergencyTap,
  });

  final bool isBangla;
  final VoidCallback onSearchTap;
  final VoidCallback onEmergencyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─────────────────────────────────────────────────────────────────────
        // SEGMENT 1: Search for Donor Card (Compact + Press Zoom)
        // ─────────────────────────────────────────────────────────────────────
        PressableCard(
          onTap: onSearchTap,
          child: Container(
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6BDBA), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Icon: circular maroon
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF960017),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isBangla ? 'রক্তদাতা অনুসন্ধান' : 'Search for Donor',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF960017),
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                isBangla
                    ? 'রক্তের গ্রুপ, অবস্থান এবং দূরত্বের ভিত্তিতে আমাদের যাচাইকৃত স্থানীয় দাতাদের তালিকা অনুসন্ধান করুন।'
                    : 'Access our verified database of local donors filtered by blood type, proximity, and availability.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF5F5E5E),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Row: Blood group badges on left + Find Now button on right
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bloodGroupBadge('A+'),
                      const SizedBox(width: 6),
                      _bloodGroupBadge('O-'),
                      const SizedBox(width: 6),
                      _bloodGroupBadge('B+'),
                    ],
                  ),
                  PressableScale(child: ElevatedButton(
                    onPressed: onSearchTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF960017),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBangla ? 'এখনই খুঁজুন' : 'Find Now',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 14),

        // ─────────────────────────────────────────────────────────────────────
        // SEGMENT 2: Emergency Blood Card (Compact + Press Zoom)
        // ─────────────────────────────────────────────────────────────────────
        PressableCard(
          onTap: () => _showEmergencyDispatchModal(context),
          child: Container(
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8F0015),
                Color(0xFF6B0010),
                Color(0xFF4A000A),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33960017),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Emergency Icon Circle + IMMEDIATE DISPATCH Pill Badge
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.crisis_alert_rounded,
                      color: Color(0xFF960017),
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(46), // ~0.18 opacity
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withAlpha(64), // ~0.25 opacity
                      ),
                    ),
                    child: const Text(
                      'IMMEDIATE DISPATCH',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                isBangla ? 'জরুরি রক্ত' : 'Emergency Blood',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                isBangla
                    ? '১০ কিমি ব্যাসার্ধের মধ্যে সমস্ত উপযুক্ত রক্তদাতা ও সহযোগী হাসপাতালে তাৎক্ষণিক অগ্রাধিকার ব্রডকাস্ট সক্রিয় করুন।'
                    : 'Trigger an instant high-priority broadcast to all compatible donors & partner hospitals within 10 km.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white.withAlpha(230),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),

              // Bottom Button: White capsule "Broadcast Emergency ->"
              SizedBox(
                width: double.infinity,
                child: PressableScale(child: ElevatedButton(
                  onPressed: () => _showEmergencyDispatchModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF960017),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        size: 20,
                        color: Color(0xFF960017),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isBangla ? 'জরুরি ব্রডকাস্ট করুন' : 'Broadcast Emergency',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF960017),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF960017),
                      ),
                    ],
                  ),
                )),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  }

  static Widget _bloodGroupBadge(String group) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFEE9EB),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6BDBA), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        group,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF960017),
        ),
      ),
    );
  }

  /// Interactive Modal Card popup triggered by "Broadcast Emergency" button
  void _showEmergencyDispatchModal(BuildContext context) {
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
                // Top drag handle
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

                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBangla ? 'জরুরি ব্রডকাস্ট অপশন' : 'Emergency Blood Dispatch',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    PressableScale(child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF5F5E5E)),
                      onPressed: () => Navigator.pop(ctx),
                    )),
                  ],
                ),
                Text(
                  isBangla
                      ? 'আপনার পরিস্থিতির জন্য উপযুক্ত জরুরি ব্রডকাস্ট চ্যানেল নির্বাচন করুন।'
                      : 'Select the emergency response protocol for your urgent situation.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF5F5E5E),
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: Personal Urgent Requisition (10km Ripple)
                _DispatchOptionCard(
                  icon: Icons.local_hospital_rounded,
                  title: isBangla ? 'ব্যক্তিগত রোগী জরুরি রিকুইজিশন' : 'Personal Emergency Request',
                  subtitle: isBangla
                      ? '১০ কিমি ব্যাসার্ধের মধ্যে উপযুক্ত রক্তদাতাদের কাছে ৩-তরঙ্গ বিশিষ্ট স্বয়ংক্রিয় অ্যালার্ট পাঠান।'
                      : 'Trigger automated 3-wave ripple dispatch to compatible donors within 10 km.',
                  badge: '10 KM RADIUS',
                  buttonText: isBangla ? 'রিকুইজিশন শুরু করুন ➔' : 'Start Requisition ➔',
                  onTap: () {
                    Navigator.pop(ctx);
                    onEmergencyTap();
                  },
                ),
                const SizedBox(height: 12),

                // Option 2: National Disaster Event
                _DispatchOptionCard(
                  icon: Icons.crisis_alert_rounded,
                  title: isBangla ? 'জাতীয় দুর্যোগ ও গণদুর্ঘটনা প্রতিক্রিয়া' : 'National Disaster Event',
                  subtitle: isBangla
                      ? 'বহু-আহত বা জরুরি দুর্যোগ কেন্দ্রে স্থান ও রক্তদান সংহতি সক্রিয় করুন।'
                      : 'Coordinate multi-point mass casualty response points and triage slots.',
                  badge: 'NATIONAL EVENT',
                  isDisasterStyle: true,
                  buttonText: isBangla ? 'দুর্যোগ কেন্দ্র দেখুন ➔' : 'View Disaster Hub ➔',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/emergency/national');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DispatchOptionCard extends StatelessWidget {
  const _DispatchOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.buttonText,
    required this.onTap,
    this.isDisasterStyle = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String buttonText;
  final VoidCallback onTap;
  final bool isDisasterStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDisasterStyle ? const Color(0xFFFFF8F7) : const Color(0xFFFDFBFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDisasterStyle ? const Color(0xFFE6BDBA) : const Color(0xFFE8DADA),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF960017), size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF960017).withAlpha(20),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF960017),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF24191A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF5F5E5E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PressableScale(child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF960017),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}



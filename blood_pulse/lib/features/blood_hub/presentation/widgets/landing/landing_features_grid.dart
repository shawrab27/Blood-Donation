// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Supporting features bento tiles for Blood Hub Landing.
class LandingFeaturesGrid extends StatelessWidget {
  const LandingFeaturesGrid({
    super.key,
    required this.isBangla,
  });

  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _featureTile(
          icon: Icons.verified_user_outlined,
          title: isBangla ? 'যাচাইকৃত নেটওয়ার্ক' : 'Verified Network',
          subtitle: isBangla
              ? 'সকল দাতা আপনার সুরক্ষা এবং মানসিক শান্তির জন্য কঠোর স্বাস্থ্য যাচাইয়ের মধ্য দিয়ে যান।'
              : 'All donors undergo strict health verification for your safety and peace of mind.',
        ),
        const SizedBox(height: 12),
        _featureTile(
          icon: Icons.near_me_outlined,
          title: isBangla ? 'স্মার্ট অবস্থান' : 'Smart Proximity',
          subtitle: isBangla
              ? 'আমাদের অ্যালগরিদম আপনার অনুরোধের কয়েক মিনিটের মধ্যে সবচেয়ে কাছের উপযুক্ত ম্যাচ সনাক্ত করে।'
              : 'Our algorithm identifies the closest compatible matches within minutes of your request.',
        ),
        const SizedBox(height: 12),
        _featureTile(
          icon: Icons.history_rounded,
          title: isBangla ? 'অনুরোধের ইতিহাস' : 'Request History',
          subtitle: isBangla
              ? 'আপনার সক্রিয় অনুরোধগুলি ট্র্যাক করুন এবং আপনার ড্যাশবোর্ডে পূর্ববর্তী সফল ম্যাচগুলি পর্যালোচনা করুন।'
              : 'Track your active requests and review past successful matches in your dashboard.',
        ),
      ],
    );
  }

  Widget _featureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DADA), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF3F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0D68AA), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Hero header for Blood Hub landing conforming to Stitch UI specification.
class LandingHeroSection extends StatelessWidget {
  const LandingHeroSection({
    super.key,
    required this.isBangla,
  });

  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // ~0.04 black
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE9EB),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFC30121),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  isBangla ? 'ব্লাড কমিউনিটি' : 'Vital Community',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isBangla ? 'ব্লাড হাব' : 'The Heart of Giving',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            isBangla
                ? 'ব্লাড হাবে আপনাকে স্বাগতম। আপনি জীবন রক্ষাকারী রক্ত খুঁজছেন বা জরুরি সহায়তার অনুরোধ করছেন, আমরা আপনাকে নিঃস্বার্থ বীরদের একটি নেটওয়ার্কের সাথে যুক্ত করি।'
                : 'Welcome to the Blood Hub. Whether you’re searching for a life-saving match or requesting urgent support, we connect you to a network of selfless heroes.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF5F5E5E),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

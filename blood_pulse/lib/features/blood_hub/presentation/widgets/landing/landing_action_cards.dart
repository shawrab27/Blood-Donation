// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Primary action cards for Blood Hub Landing: "Search for Donor" and "Emergency Blood".
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
      children: [
        // Card 1: Search for Donor
        _ActionCard(
          icon: Icons.person_search_rounded,
          iconBg: const Color(0xFFC30121),
          iconColor: Colors.white,
          title: isBangla ? 'রক্তদাতা খুঁজুন' : 'Search for Donor',
          subtitle: isBangla
              ? 'রক্তের গ্রুপ, অবস্থান এবং উপস্থিতির ভিত্তিতে আমাদের যাচাইকৃত স্থানীয় দাতাদের তালিকা দেখুন।'
              : 'Access our verified database of local donors filtered by blood type, proximity, and availability.',
          accentChild: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bloodGroupBadge('A+'),
              const SizedBox(width: 4),
              _bloodGroupBadge('O-'),
              const SizedBox(width: 4),
              _bloodGroupBadge('B+'),
            ],
          ),
          buttonText: isBangla ? 'এখনই খুঁজুন' : 'Find Now',
          onTap: onSearchTap,
        ),
        const SizedBox(height: 16),
        // Card 2: Emergency Blood
        _ActionCard(
          icon: Icons.emergency_share_rounded,
          iconBg: const Color(0xFFC30121),
          iconColor: Colors.white,
          isUrgentStyle: true,
          title: isBangla ? 'জরুরি রক্ত' : 'Emergency Blood',
          subtitle: isBangla
              ? 'জাতীয় দুর্যোগ বা ব্যক্তিগত জরুরি পরিস্থিতিতে তাৎক্ষণিক রক্তদাতা সমন্বয় সক্রিয় করুন।'
              : 'Instantly notify all eligible donors in your area for urgent transfusion needs or planned procedures.',
          accentChild: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE9EB),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC30121),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isBangla ? 'জরুরি ডিসপ্যাচ' : 'Active Dispatch',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC30121),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          buttonText: isBangla ? 'সাহায্য নিন' : 'Get Help Now',
          onTap: onEmergencyTap,
        ),
      ],
    );
  }

  Widget _bloodGroupBadge(String group) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFFEE9EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        group,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC30121),
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.accentChild,
    required this.buttonText,
    required this.onTap,
    this.isUrgentStyle = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget accentChild;
  final String buttonText;
  final VoidCallback onTap;
  final bool isUrgentStyle;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isUrgentStyle
                  ? const Color(0xFFC30121).withAlpha(40)
                  : const Color(0xFFE8DADA),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: widget.accentChild),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF5F5E5E),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: widget.onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC30121),
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
                        widget.buttonText,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

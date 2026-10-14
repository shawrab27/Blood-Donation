// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Stitch Screen 1: Profile Donation Stats (3 Equal Tiles, 120px High)
/// 1:1 match to Stitch:
/// - Tile 1: Bags Donated (caption: 'donations completed')
/// - Tile 2: Next Eligible (64px circular canvas progress ring showing days left)
/// - Tile 3: Last Donation (pencil edit icon, formatted date, hospital name)
class ProfileStatsRow extends StatelessWidget {
  final int totalBags;
  final int daysRemaining;
  final double? progressPercent;
  final bool showCountdown;
  final String? lastDonationDateFormatted;
  final String? hospitalName;
  final VoidCallback? onEditLastDonation;

  const ProfileStatsRow({
    super.key,
    required this.totalBags,
    required this.daysRemaining,
    this.progressPercent,
    this.showCountdown = true,
    this.lastDonationDateFormatted,
    this.hospitalName,
    this.onEditLastDonation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // ── Tile 1: Bags Donated ──
            Expanded(
              child: _buildTile(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$totalBags',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC30121),
                          height: 1.0,
                        ),
                      ),
                    ),
                    Column(
                      children: const [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Bags Donated',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF24191A),
                              height: 1.1,
                            ),
                          ),
                        ),
                        SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'donations completed',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF5F5E5E),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Tile 2: Next Eligible Ring (64px CustomPainter) ──
            Expanded(
              child: _buildTile(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CustomPaint(
                        painter: _CircularCountdownPainter(
                          daysRemaining: daysRemaining,
                          cooldownDays: 90,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  daysRemaining > 0 ? '$daysRemaining' : '✓',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: daysRemaining > 0 ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                    color: daysRemaining > 0
                                        ? const Color(0xFF24191A)
                                        : const Color(0xFF1B8A4E),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              if (daysRemaining > 0)
                                const Text(
                                  'days',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF5F5E5E),
                                    height: 1.0,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        daysRemaining > 0 ? 'until next donation' : 'Eligible today',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: daysRemaining <= 0 ? FontWeight.w600 : FontWeight.normal,
                          color: daysRemaining <= 0 ? const Color(0xFF1B8A4E) : const Color(0xFF5F5E5E),
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── Tile 3: Last Donation ──
            Expanded(
              child: _buildTile(
                child: Stack(
                  children: [
                    // Edit pencil icon in top-right
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onEditLastDonation,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFFC30121)),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(height: 2),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Last Donation',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5F5E5E),
                                height: 1.1,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              lastDonationDateFormatted ?? 'None',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF24191A),
                                height: 1.1,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              hospitalName?.isNotEmpty == true ? hospitalName! : 'Direct / Clinic',
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF5F5E5E),
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTile({required Widget child}) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Custom painter for the 64px circular countdown progress ring
class _CircularCountdownPainter extends CustomPainter {
  final int daysRemaining;
  final int cooldownDays;

  _CircularCountdownPainter({
    required this.daysRemaining,
    required this.cooldownDays,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFFFEE2E2)
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final double elapsedDays = (cooldownDays - daysRemaining).clamp(0, cooldownDays).toDouble();
    final double sweepFraction = elapsedDays / cooldownDays;
    final double sweepAngle = 2 * math.pi * sweepFraction;

    final progressPaint = Paint()
      ..color = daysRemaining <= 0 ? const Color(0xFF1B8A4E) : const Color(0xFFC30121)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularCountdownPainter oldDelegate) {
    return oldDelegate.daysRemaining != daysRemaining ||
        oldDelegate.cooldownDays != cooldownDays;
  }
}

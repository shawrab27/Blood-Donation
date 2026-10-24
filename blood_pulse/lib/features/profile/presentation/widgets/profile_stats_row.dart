// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/widgets/pressable_card.dart';
import 'package:blood_pulse/core/widgets/count_up_text.dart';

// USER RULE - do not change: 4 profile stat boxes in primary red tone
// Box 1: Bags Donated
// Box 2: Eligible today
// Box 3: Last Donation
// Box 4: Pause Emergency Alerts (slide toggle)
// All wrapped in shared PressableCard for light press zoom
class ProfileStatsRow extends StatelessWidget {
  final int totalBags;
  final int daysRemaining;
  final double? progressPercent;
  final bool showCountdown;
  final String? lastDonationDateFormatted;
  final String? hospitalName;
  final VoidCallback? onEditLastDonation;
  final bool isAlertsPaused;
  final String? pauseDurationText;
  final VoidCallback? onTogglePause;

  const ProfileStatsRow({
    super.key,
    required this.totalBags,
    required this.daysRemaining,
    this.progressPercent,
    this.showCountdown = true,
    this.lastDonationDateFormatted,
    this.hospitalName,
    this.onEditLastDonation,
    this.isAlertsPaused = false,
    this.pauseDurationText,
    this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final isEligible = daysRemaining <= 0;

        final tiles = [
          // ── Box 1: Bags Donated ──
          PressableCard(
            child: _buildTile(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CountUpText(
                      endValue: totalBags,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC30121),
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Bags Donated',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'units given',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFF7F2228),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Box 2: Eligible today ──
          PressableCard(
            child: _buildTile(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isEligible ? 'Yes' : 'No',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC30121),
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Eligible today',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isEligible ? 'Ready to donate' : '$daysRemaining days left',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFF7F2228),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Box 3: Last Donation ──
          PressableCard(
            child: _buildTile(
              child: Stack(
                children: [
                  if (onEditLastDonation != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onEditLastDonation,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.edit_outlined, size: 14, color: Color(0xFFC30121)),
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            lastDonationDateFormatted ?? 'None',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC30121),
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Last Donation',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF24191A),
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hospitalName?.isNotEmpty == true ? hospitalName! : 'Clinic / Direct',
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Color(0xFF7F2228),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Box 4: Pause Emergency Alerts (slide toggle) ──
          PressableCard(
            onTap: onTogglePause,
            child: _buildTile(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: isAlertsPaused,
                      onChanged: onTogglePause != null ? (_) => onTogglePause!() : null,
                      activeColor: const Color(0xFFC30121),
                    ),
                  ),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Pause Alerts',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isAlertsPaused ? 'Paused' : 'Active',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFF7F2228),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];

        if (isDesktop) {
          return Row(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        );
      },
    );
  }

  Widget _buildTile({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC30121).withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC30121).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

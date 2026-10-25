// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../domain/providers/profile_provider.dart';

/// Stitch Screen: XP & Donor Level Screen
/// Displays XP progress, badge tiers, and transparent "How to Earn XP" rules.
/// Zero doctor discounts or unverified claims.
class XpLevelScreen extends ConsumerWidget {
  const XpLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;

    final int xp = profile?.xp ?? 0;
    final int level = profile?.level ?? 1;
    final double levelProgress = profile?.levelProgress ?? 0.0;
    final String tier = profile?.tier ?? 'Active Donor';
    final int nextLevelXp = profile?.nextLevelXp ?? 100;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: PressableScale(child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF24191A)),
          onPressed: () => Navigator.of(context).pop(),
        )),
        title: const Text(
          'XP & Level Standing',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF24191A),
          ),
        ),
      ),
      body: ResponsiveCenterWrapper(
        maxWidth: 540,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Hero Level & XP Card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC30121), Color(0xFF8B0015)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33C30121),
                    blurRadius: 12,
                    offset: Offset(0, 6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'Level $level Donor',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.military_tech_rounded, size: 14, color: Color(0xFFFFD700)),
                            const SizedBox(width: 4),
                            Text(
                              tier,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$xp',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Total XP',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      height: 10,
                      color: Colors.white.withValues(alpha: 0.25),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: levelProgress.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress to Level ${level + 1}',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white70),
                      ),
                      Text(
                        '$nextLevelXp XP to next level',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Tier Ladder Section ──
            const Text(
              'Badge Tiers Hierarchy',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF24191A),
              ),
            ),
            Builder(
              builder: (context) {
                final String currentTier;
                final tLower = tier.toLowerCase();
                if (tLower.contains('diamond')) {
                  currentTier = 'Diamond';
                } else if (tLower.contains('platinum')) {
                  currentTier = 'Platinum';
                } else if (tLower.contains('gold')) {
                  currentTier = 'Gold';
                } else if (tLower.contains('silver')) {
                  currentTier = 'Silver';
                } else if (tLower.contains('bronze')) {
                  currentTier = 'Bronze';
                } else {
                  if (xp >= 3000) {
                    currentTier = 'Diamond';
                  } else if (xp >= 1500) {
                    currentTier = 'Platinum';
                  } else if (xp >= 600) {
                    currentTier = 'Gold';
                  } else if (xp >= 300) {
                    currentTier = 'Silver';
                  } else {
                    currentTier = 'Bronze';
                  }
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0E5E5)),
                  ),
                  child: Column(
                    children: [
                      _buildTierRow('Bronze Donor', '0 – 299 XP', currentTier == 'Bronze'),
                      const Divider(height: 16, color: Color(0xFFF0E5E5)),
                      _buildTierRow('Silver Donor', '300 – 599 XP', currentTier == 'Silver'),
                      const Divider(height: 16, color: Color(0xFFF0E5E5)),
                      _buildTierRow('Gold Donor', '600 – 1499 XP', currentTier == 'Gold'),
                      const Divider(height: 16, color: Color(0xFFF0E5E5)),
                      _buildTierRow('Platinum Donor', '1500 – 2999 XP', currentTier == 'Platinum'),
                      const Divider(height: 16, color: Color(0xFFF0E5E5)),
                      _buildTierRow('Diamond Donor', '3000+ XP', currentTier == 'Diamond'),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── How to Earn XP Section ──
            const Text(
              'How to Earn XP',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF24191A),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0E5E5)),
              ),
              child: Column(
                children: [
                  _buildXpRule(
                    title: 'Verified Blood Donation',
                    description: 'Awarded immediately upon clinical or requester confirmation of a completed donation.',
                    xpText: '+100 XP',
                    isActive: true,
                  ),
                  const Divider(height: 20, color: Color(0xFFF0E5E5)),
                  _buildXpRule(
                    title: 'Community Story Milestone',
                    description: 'Share recovery or donation journey experiences that inspire new donors.',
                    xpText: 'Coming Soon',
                    isActive: false,
                  ),
                  const Divider(height: 20, color: Color(0xFFF0E5E5)),
                  _buildXpRule(
                    title: 'Emergency Volunteer Response',
                    description: 'Respond rapidly to priority national or regional emergency calls.',
                    xpText: 'Coming Soon',
                    isActive: false,
                  ),
                  const Divider(height: 20, color: Color(0xFFF0E5E5)),
                  _buildXpRule(
                    title: 'Identity Verification Badge',
                    description: 'Complete diagnostic blood group and identity verification steps.',
                    xpText: 'Coming Soon',
                    isActive: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(String title, String threshold, bool isCurrent) {
    return Row(
      children: [
        Icon(
          isCurrent ? Icons.stars_rounded : Icons.radio_button_unchecked_rounded,
          size: 18,
          color: isCurrent ? const Color(0xFFC30121) : const Color(0xFF8C8A8A),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? const Color(0xFFC30121) : const Color(0xFF24191A),
            ),
          ),
        ),
        Text(
          threshold,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? const Color(0xFFC30121) : const Color(0xFF5F5E5E),
          ),
        ),
        if (isCurrent) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text(
              'Current',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildXpRule({
    required String title,
    required String description,
    required String xpText,
    required bool isActive,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFF0F1) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isActive ? Icons.bolt_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: isActive ? const Color(0xFFC30121) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF5F5E5E), height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            xpText,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? const Color(0xFF1B8A4E) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}

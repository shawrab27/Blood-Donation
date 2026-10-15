// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/providers/profile_provider.dart';

/// Full nationwide leaderboard screen displaying ranked donors in Bangladesh.
/// Features pinned caller rank, tie-break transparency, and sanitized privacy.
class GlobalRankScreen extends ConsumerStatefulWidget {
  const GlobalRankScreen({super.key});

  @override
  ConsumerState<GlobalRankScreen> createState() => _GlobalRankScreenState();
}

class _GlobalRankScreenState extends ConsumerState<GlobalRankScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalRankItem> _allDonors = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchPage(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchPage(_currentPage + 1);
    }
  }

  Future<void> _fetchPage(int page) async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final items = await ref.read(globalRankProvider(page).future);
      if (mounted) {
        setState(() {
          if (page == 1) {
            _allDonors.clear();
          }
          _allDonors.addAll(items);
          _currentPage = page;
          _hasMore = items.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final callerRank = profile?.rank ?? 0;
    final callerBags = profile?.bagsDonated ?? profile?.totalBagsDonated ?? 0;
    final callerTier = profile?.tier ?? 'Active Donor';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: const CustomAppBar(
        title: 'Global Leaderboard',
        showLogo: false,
        showBackButton: true,
        showNotification: false,
        showProfile: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // ── Pinned Caller Rank Banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC30121), Color(0xFF8B0000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x33C30121),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            callerRank > 0 ? '#$callerRank' : '—',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Standing',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.white70),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              callerRank > 0 ? 'Rank #$callerRank • $callerTier' : 'Unranked • Donate to rank',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '$callerBags Bags',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Leaderboard List ──
              Expanded(
                child: _allDonors.isEmpty && _isLoadingMore
                    ? const Center(child: AppLoader())
                    : _allDonors.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.emoji_events_outlined, size: 48, color: Color(0xFFE2D6D6)),
                                SizedBox(height: 12),
                                Text(
                                  'No Ranked Donors Yet',
                                  style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Verified donations earn points and climb the nationwide leaderboard!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _allDonors.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index >= _allDonors.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: SizedBox(width: 20, height: 20, child: AppLoader()),
                                  ),
                                );
                              }
                              final donor = _allDonors[index];
                              return _buildLeaderboardTile(donor);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(GlobalRankItem donor) {
    final rank = donor.rank;
    final isTop3 = rank <= 3;

    final Color badgeColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFF8C8A8A);

    return InkWell(
      onTap: () {
        if (donor.isCaller) {
          context.push('/profile');
        } else {
          context.push('/profile/${donor.id}');
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: donor.isCaller ? const Color(0xFFFFF0F1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: donor.isCaller ? const Color(0xFFC30121) : const Color(0xFFF0E5E5),
            width: donor.isCaller ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank Number / Badge
            Container(
              width: 34,
              alignment: Alignment.center,
              child: isTop3
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      '#$rank',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5F5E5E),
                      ),
                    ),
            ),
            const SizedBox(width: 10),

            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFF0F1),
              backgroundImage: donor.photo != null && donor.photo!.isNotEmpty
                  ? NetworkImage(donor.photo!)
                  : null,
              child: donor.photo == null || donor.photo!.isEmpty
                  ? Text(
                      donor.name.isNotEmpty ? donor.name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC30121),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Name & Tier
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          donor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                      ),
                      if (donor.isCaller) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC30121),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text('You', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${donor.tier} • ${donor.ratingAvg.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF5F5E5E),
                    ),
                  ),
                ],
              ),
            ),

            // Blood Group & Bags Count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFE2D6D6)),
                  ),
                  child: Text(
                    donor.bloodGroup,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC30121),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${donor.verifiedBags} ${donor.verifiedBags == 1 ? "Bag" : "Bags"}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF24191A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

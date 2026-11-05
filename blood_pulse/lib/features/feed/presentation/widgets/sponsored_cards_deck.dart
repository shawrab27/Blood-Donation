// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../domain/entities/sponsored_card_model.dart';
import '../providers/sponsored_cards_provider.dart';

/// Deck of sponsored cards in the feed sitting directly below the post composer.
/// Completely hidden when flag is off, list is empty, or request fails.
class SponsoredCardsDeck extends ConsumerStatefulWidget {
  const SponsoredCardsDeck({super.key});

  @override
  ConsumerState<SponsoredCardsDeck> createState() => _SponsoredCardsDeckState();
}

class _SponsoredCardsDeckState extends ConsumerState<SponsoredCardsDeck> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openDetailSheet(BuildContext context, SponsoredCardModel card, bool isBn) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black54, // Dark scrim without blur
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _SponsoredCardDetailSheet(card: card, isBn: isBn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sponsoredCardsProvider);
    final cards = state.cards;

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final isBn = Localizations.localeOf(context).languageCode == 'bn';
    final hasMultiple = cards.length > 1;
    final hasThreeOrMore = cards.length >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked deck with static peeking layers
          SizedBox(
            height: 190 + (hasThreeOrMore ? 16 : (hasMultiple ? 8 : 0)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Layer 2: bottom-most static peeking layer (if >= 3 cards)
                if (hasThreeOrMore)
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    height: 190,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD1D5DB), width: 0.8),
                      ),
                    ),
                  ),

                // Layer 1: middle static peeking layer (if >= 2 cards)
                if (hasMultiple)
                  Positioned(
                    top: 7,
                    left: 7,
                    right: 7,
                    height: 190,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
                      ),
                    ),
                  ),

                // Foreground active card PageView
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 190,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (idx) {
                      setState(() => _currentPage = idx);
                    },
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return _buildCardItem(context, card, isBn);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Page dots indicator
          if (hasMultiple) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (idx) {
                final isActive = idx == _currentPage;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF0D68AA) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, SponsoredCardModel card, bool isBn) {
    return PressableScale(
      onTap: () => _openDetailSheet(context, card, isBn),
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1F2937),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image (if present, else cleanly hides)
              if (card.image != null && card.image!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: card.image!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                  placeholder: (context, url) => Container(color: const Color(0xFF2B2B2B)),
                ),

              // Dark gradient scrim for strong text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top tag row in grey/Tertiary tones (never red)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Text(
                            isBn ? 'স্পন্সরড' : 'Sponsored',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (card.kind.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D68AA).withOpacity(0.35),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: const Color(0xFF0D68AA).withOpacity(0.6),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              card.kind.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE0F2FE),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Title, short text, and "See more" capsule button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        if (card.shortText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            card.shortText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        PressableScale(
                          onTap: () => _openDetailSheet(context, card, isBn),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isBn ? 'আরও দেখুন' : 'See more',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail modal bottom sheet with dark scrim (no blur).
class _SponsoredCardDetailSheet extends StatelessWidget {
  const _SponsoredCardDetailSheet({required this.card, required this.isBn});

  final SponsoredCardModel card;
  final bool isBn;

  String _formatValidUntil(DateTime? dt) {
    if (dt == null) return '';
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthsEn[dt.month - 1];
    if (isBn) {
      return 'মেয়াদ: ${dt.day} $month ${dt.year}';
    }
    return 'Valid until $month ${dt.day}, ${dt.year}';
  }

  Future<void> _handleAction() async {
    if (card.ctaType == 'link') {
      final uri = Uri.tryParse(card.ctaValue);
      if (uri != null && uri.scheme == 'https') {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } else if (card.ctaType == 'call') {
      final clean = card.ctaValue.replaceAll(RegExp(r'[^0-9+]'), '');
      if (clean.isNotEmpty) {
        final uri = Uri(scheme: 'tel', path: clean);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validUntil = _formatValidUntil(card.endsAt);
    final hasAction = (card.ctaType == 'link' || card.ctaType == 'call') && card.ctaValue.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Image (if present, else cleanly hides with no gap)
              if (card.image != null && card.image!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: card.image!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, err) => const SizedBox.shrink(),
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: const Color(0xFFF3F4F6),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Badges: "Sponsored" and kind chip in grey/tertiary tones (never red)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      isBn ? 'স্পন্সরড' : 'Sponsored',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  if (card.kind.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        card.kind.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D68AA),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Sponsor Name
              if (card.sponsorName.isNotEmpty) ...[
                Text(
                  card.sponsorName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // Title in Georgia
              Text(
                card.title,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              // Description in Inter
              Text(
                card.body.isNotEmpty ? card.body : card.shortText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),

              // Valid Until date
              if (validUntil.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  validUntil,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],

              // Action button (capsule with arrow icon AFTER text, PressableScale, tap target min 48dp)
              if (hasAction) ...[
                const SizedBox(height: 20),
                PressableScale(
                  onTap: _handleAction,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            card.ctaType == 'call'
                                ? (isBn ? 'কল করুন' : 'Call Sponsor')
                                : (isBn ? 'ওয়েবসাইট দেখুন' : 'Visit Website'),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          card.ctaType == 'call' ? Icons.phone_rounded : Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

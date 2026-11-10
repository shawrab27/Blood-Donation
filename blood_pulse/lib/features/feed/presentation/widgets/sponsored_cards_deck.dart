// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:blood_pulse/l10n/app_localizations_en.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/sponsored_card_model.dart';
import '../providers/sponsored_cards_provider.dart';
import 'sponsored_card_detail_sheet.dart';
import 'sponsored_card_tile.dart';

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

  void _openDetailSheet(BuildContext context, SponsoredCardModel card) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardLight,
      barrierColor: Colors.black54, // Dark scrim without blur
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SponsoredCardDetailSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sponsoredCardsProvider);
    final cards = state.cards;

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final double cardHeight = textScale > 1.1 ? 228.0 : 204.0;
    final hasMultiple = cards.length > 1;
    final hasThreeOrMore = cards.length >= 3;
    final double stackExtra = hasThreeOrMore ? 16.0 : (hasMultiple ? 8.0 : 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: cardHeight + stackExtra,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (hasThreeOrMore)
                  _DeckPeekLayer(
                    inset: 14,
                    height: cardHeight,
                    color: const Color(0xFFE5E7EB),
                    borderColor: const Color(0xFFD1D5DB),
                  ),
                if (hasMultiple)
                  _DeckPeekLayer(
                    inset: 7,
                    height: cardHeight,
                    color: const Color(0xFFF3F4F6),
                    borderColor: const Color(0xFFE5E7EB),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: cardHeight,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (idx) {
                      setState(() => _currentPage = idx);
                    },
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return SponsoredCardTile(
                        card: card,
                        l10n: l10n,
                        cardHeight: cardHeight,
                        onTap: () => _openDetailSheet(context, card),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
                    color: isActive ? AppColors.tertiary : const Color(0xFFD1D5DB),
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
}

class _DeckPeekLayer extends StatelessWidget {
  const _DeckPeekLayer({
    required this.inset,
    required this.height,
    required this.color,
    required this.borderColor,
  });

  final double inset;
  final double height;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: inset,
      left: inset,
      right: inset,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.8),
        ),
      ),
    );
  }
}

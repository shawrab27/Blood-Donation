// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:blood_pulse/l10n/app_localizations_en.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/sponsored_card_model.dart';

/// Maps backend [kind] codes to localized display labels.
String localizedSponsoredKindLabel(AppLocalizations l10n, String kind) {
  switch (kind.trim().toLowerCase()) {
    case 'hospital_update':
      return l10n.sponsoredKindHospitalUpdate;
    case 'medicine_offer':
      return l10n.sponsoredKindMedicineOffer;
    case 'doctor':
      return l10n.sponsoredKindDoctor;
    default:
      final cleaned = kind.replaceAll('_', ' ').trim();
      return cleaned.isEmpty ? l10n.sponsoredBadge : cleaned;
  }
}

/// Detail modal bottom sheet for a [SponsoredCardModel] with dark scrim (no blur).
class SponsoredCardDetailSheet extends StatelessWidget {
  const SponsoredCardDetailSheet({super.key, required this.card});

  final SponsoredCardModel card;

  String _formatValidUntil(AppLocalizations l10n, DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final formatted = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    return l10n.sponsoredValidUntil(formatted);
  }

  Future<void> _handleAction() async {
    if (card.ctaType == 'link') {
      final uri = Uri.tryParse(card.ctaValue.trim());
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
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final validUntil = _formatValidUntil(l10n, card.endsAt);
    final hasAction =
        (card.ctaType == 'link' || card.ctaType == 'call') &&
        card.ctaValue.trim().isNotEmpty;
    final hasImage = card.image != null && card.image!.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle + close button when no image header
              Row(
                children: [
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  if (!hasImage)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.secondary,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    ),
                ],
              ),

              if (hasImage) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: card.image!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        placeholder: (_, __) => Container(
                          height: 180,
                          color: const Color(0xFFF3F4F6),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Badges: "Sponsored" and kind chip in grey/tertiary tones (never red)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SheetChip(
                    label: l10n.sponsoredBadge,
                    background: const Color(0xFFF3F4F6),
                    border: const Color(0xFFE5E7EB),
                    textColor: const Color(0xFF4B5563),
                  ),
                  if (card.kind.trim().isNotEmpty)
                    _SheetChip(
                      label: localizedSponsoredKindLabel(l10n, card.kind),
                      background: const Color(0xFFF0F9FF),
                      border: const Color(0xFFBAE6FD),
                      textColor: AppColors.tertiary,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (card.sponsorName.trim().isNotEmpty) ...[
                Text(
                  card.sponsorName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
              ],

              Text(
                card.title,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                card.body.trim().isNotEmpty ? card.body : card.shortText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),

              if (validUntil.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        validUntil,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (hasAction) ...[
                const SizedBox(height: 20),
                PrimaryButton(
                  label: card.ctaType == 'call'
                      ? l10n.sponsoredCallSponsor
                      : l10n.sponsoredVisitWebsite,
                  icon: card.ctaType == 'call'
                      ? Icons.phone_rounded
                      : Icons.arrow_forward_rounded,
                  backgroundColor: AppColors.tertiary,
                  foregroundColor: AppColors.onPrimary,
                  height: 50,
                  onPressed: _handleAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

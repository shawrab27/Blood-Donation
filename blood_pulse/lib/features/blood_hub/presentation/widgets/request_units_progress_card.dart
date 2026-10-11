// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Shared responsive widget (Part G) displaying blood request unit progress:
/// `received / pending / needed` (e.g. `1 / 2 / 3 units`),
/// Request Mode badge (`SELF` vs `PROXY`), optional Support Status tag
/// (`Voluntary Only / Charity`), closed status banner (`No longer needed — thank you`),
/// and friendly EN/BN rate-limit (`retry_after`) notice.
///
/// Rendered in all 5 required places (and never on the Feed):
/// 1. Emergency request form (after submit)
/// 2. Notification popup
/// 3. Tracking screen
/// 4. Disaster Overview
/// 5. Closed QR page
class RequestUnitsProgressCard extends StatelessWidget {
  final int unitsReceived;
  final int unitsPending;
  final int unitsNeeded;
  final String? requestMode; // 'SELF' or 'PROXY'
  final String? supportStatus; // 'CAN_SUPPORT' or 'VOLUNTARY_ONLY'
  final String? status; // 'OPEN', 'FULFILLED', 'CLOSED', 'EXPIRED'
  final bool isClosed;
  final int? retryAfterSeconds;
  final bool compact;
  final String? title;

  const RequestUnitsProgressCard({
    super.key,
    required this.unitsReceived,
    required this.unitsPending,
    required this.unitsNeeded,
    this.requestMode,
    this.supportStatus,
    this.status,
    this.isClosed = false,
    this.retryAfterSeconds,
    this.compact = false,
    this.title,
  });

  bool get _effectivelyClosed {
    final normStatus = (status ?? '').toUpperCase();
    return isClosed ||
        (unitsNeeded > 0 && unitsReceived >= unitsNeeded) ||
        normStatus == 'FULFILLED' ||
        normStatus == 'CLOSED' ||
        normStatus == 'EXPIRED' ||
        normStatus == 'CANCELLED';
  }

  /// Formats a friendly bilingual EN/BN rate-limit message from `retry_after` seconds (Part F).
  static String formatRateLimitMessage(int retryAfterSeconds) {
    final secs = retryAfterSeconds < 1 ? 1 : retryAfterSeconds;
    return 'Too many requests. Please wait $secs seconds before trying again. / '
        'অতিরিক্ত অনুরোধ করা হয়েছে। অনুগ্রহ করে $secs সেকেন্ড অপেক্ষা করে আবার চেষ্টা করুন।';
  }

  @override
  Widget build(BuildContext context) {
    final safeNeeded = unitsNeeded < 1 ? 1 : unitsNeeded;
    final safeReceived = unitsReceived.clamp(0, safeNeeded);
    final safePending = unitsPending.clamp(0, safeNeeded - safeReceived);
    final closed = _effectivelyClosed;
    final modeUpper = (requestMode ?? '').trim().toUpperCase();
    final supportUpper = (supportStatus ?? '').trim().toUpperCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        return Container(
          key: const Key('request_units_progress_card'),
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: closed
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
                  : const Color(0xFFC30121).withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: Title + "received / pending / needed units" pill
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        closed ? Icons.verified_rounded : Icons.bloodtype_rounded,
                        size: compact ? 18 : 20,
                        color: closed
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC30121),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title ?? 'Blood Units Progress',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: compact ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2B2B2B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    key: const Key('request_units_fraction_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: closed
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFC30121).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      '$safeReceived / $safePending / $safeNeeded units',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color: closed
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC30121),
                      ),
                    ),
                  ),
                ],
              ),

              if (modeUpper.isNotEmpty || supportUpper.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (modeUpper == 'SELF' || modeUpper == 'PROXY')
                      Container(
                        key: Key('request_mode_badge_$modeUpper'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D68AA).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          modeUpper == 'PROXY'
                              ? 'Request Mode: PROXY (For Another Patient)'
                              : 'Request Mode: SELF (For Myself)',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D68AA),
                          ),
                        ),
                      ),
                    if (supportUpper == 'VOLUNTARY_ONLY' ||
                        supportUpper == 'CAN_SUPPORT')
                      Container(
                        key: Key('support_status_badge_$supportUpper'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: supportUpper == 'VOLUNTARY_ONLY'
                              ? const Color(0xFF6A1B9A).withValues(alpha: 0.12)
                              : const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          supportUpper == 'VOLUNTARY_ONLY'
                              ? 'Voluntary Only / Charity'
                              : 'Can Support',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: supportUpper == 'VOLUNTARY_ONLY'
                                ? const Color(0xFF6A1B9A)
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // Segmented visual bar: Received (Green) | Pending (Amber) | Remaining (Grey)
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: SizedBox(
                  height: compact ? 8 : 10,
                  child: Row(
                    children: [
                      if (safeReceived > 0)
                        Expanded(
                          flex: safeReceived,
                          child: Container(color: const Color(0xFF2E7D32)),
                        ),
                      if (safePending > 0)
                        Expanded(
                          flex: safePending,
                          child: Container(color: const Color(0xFFF57C00)),
                        ),
                      if (safeNeeded - safeReceived - safePending > 0)
                        Expanded(
                          flex: safeNeeded - safeReceived - safePending,
                          child: Container(color: const Color(0xFFE0E0E0)),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Legend / counters for Received, Pending, Needed
              Wrap(
                spacing: isNarrow ? 8 : 14,
                runSpacing: 6,
                children: [
                  _buildMetricChip(
                    label: 'Received',
                    value: safeReceived,
                    dotColor: const Color(0xFF2E7D32),
                  ),
                  _buildMetricChip(
                    label: 'Pending',
                    value: safePending,
                    dotColor: const Color(0xFFF57C00),
                  ),
                  _buildMetricChip(
                    label: 'Needed',
                    value: safeNeeded,
                    dotColor: const Color(0xFFC30121),
                  ),
                ],
              ),

              // Closed state banner (Part E / G5)
              if (closed) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('request_closed_thank_you_banner'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'No longer needed — thank you',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Friendly Rate Limit retry_after notice (Part F)
              if (retryAfterSeconds != null && retryAfterSeconds! > 0) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('rate_limit_retry_after_banner'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF57C00)),
                  ),
                  child: Text(
                    formatRateLimitMessage(retryAfterSeconds!),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricChip({
    required String label,
    required int value,
    required Color dotColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: $value',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B2B2B),
          ),
        ),
      ],
    );
  }
}

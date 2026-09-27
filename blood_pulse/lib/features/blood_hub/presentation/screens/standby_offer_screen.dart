// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kNeutral = Color(0xFF8E7D7F);

String _componentLabel(String c) {
  switch (c) {
    case 'WHOLE':
      return 'Whole Blood';
    case 'RBC':
      return 'Red Blood Cells';
    case 'PLATELETS':
      return 'Platelets';
    case 'PLASMA':
      return 'Plasma';
    default:
      return c;
  }
}

String _urgencyLabel(String u) {
  switch (u) {
    case 'CRITICAL_2H':
      return '🔴 Critical — within 2 h';
    case 'URGENT_6H':
      return '🟠 Urgent — within 6 h';
    case 'TODAY_24H':
      return '🟡 Today — within 24 h';
    case 'SCHEDULED':
      return '🟢 Scheduled';
    default:
      return u;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STANDBY OFFER SCREEN  (/standby/:offerId)
// ─────────────────────────────────────────────────────────────────────────────

class StandbyOfferScreen extends ConsumerStatefulWidget {
  const StandbyOfferScreen({super.key, required this.offerId});

  final int offerId;

  @override
  ConsumerState<StandbyOfferScreen> createState() =>
      _StandbyOfferScreenState();
}

class _StandbyOfferScreenState extends ConsumerState<StandbyOfferScreen> {
  bool _responding = false;

  Future<void> _respond(String action, StandbyOfferDetail offer) async {
    setState(() => _responding = true);
    try {
      await ref
          .read(bloodHubApiServiceProvider)
          .respondToStandby(offer.id, action);
      if (!mounted) return;
      ref.invalidate(standbyOfferProvider(widget.offerId));
      final msg = action == 'ACCEPT'
          ? 'You accepted — the requester has been notified.'
          : 'Offer declined. Thank you.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: _kPrimary));
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncOffer = ref.watch(standbyOfferProvider(widget.offerId));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _kSecondary),
        title: const Text(
          'Standby Offer',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kSecondary,
          ),
        ),
      ),
      body: SafeArea(
        child: asyncOffer.when(
          loading: () => const _Skeleton(),
          error: (e, _) => _ErrorRetry(
            message: '$e',
            onRetry: () => ref.invalidate(standbyOfferProvider(widget.offerId)),
          ),
          data: (offer) => _OfferBody(
            offer: offer,
            responding: _responding,
            onRespond: (action) => _respond(action, offer),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFER BODY
// ─────────────────────────────────────────────────────────────────────────────

class _OfferBody extends StatelessWidget {
  const _OfferBody({
    required this.offer,
    required this.responding,
    required this.onRespond,
  });

  final StandbyOfferDetail offer;
  final bool responding;
  final void Function(String action) onRespond;

  @override
  Widget build(BuildContext context) {
    final isExpired = offer.status == 'EXPIRED' ||
        offer.timeRemaining == Duration.zero;
    final isSettled =
        offer.status == 'ACCEPTED' || offer.status == 'DECLINED' || isExpired;

    return ResponsiveCenterWrapper(
      maxWidth: 560,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Urgency Banner ─────────────────────────────────────────
            _UrgencyBanner(offer: offer, isExpired: isExpired),

            const SizedBox(height: 16),

            // ── Countdown timer ────────────────────────────────────────
            if (!isSettled) _CountdownTimer(offer: offer),

            if (!isSettled) const SizedBox(height: 16),

            // ── Status chip if settled ─────────────────────────────────
            if (isSettled) _StatusChip(status: offer.status),

            if (isSettled) const SizedBox(height: 16),

            // ── Blood & Request Details ────────────────────────────────
            _SectionCard(
              title: 'Request Details',
              children: [
                _DetailRow('Blood Group', offer.bloodGroup),
                _DetailRow('Component', _componentLabel(offer.component)),
                _DetailRow('Units', '${offer.unitsNeeded} bag(s)'),
                _DetailRow('Urgency', _urgencyLabel(offer.urgency)),
                _DetailRow(
                    'Distance', '~${offer.distanceKm.toStringAsFixed(1)} km'),
                _DetailRow('Hospital', offer.hospitalName),
              ],
            ),

            const SizedBox(height: 12),

            // ── Masked Requester ───────────────────────────────────────
            _SectionCard(
              title: 'Requester',
              children: [
                _DetailRow(
                  'Contact',
                  offer.maskedRequester.isNotEmpty
                      ? offer.maskedRequester
                      : 'Revealed after you accept',
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Full contact details are revealed only after acceptance '
                    'to protect requester privacy.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: _kNeutral,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Action Buttons ─────────────────────────────────────────
            if (!isSettled && offer.canAccept)
              _AcceptButton(
                  responding: responding,
                  onTap: () => onRespond('ACCEPT')),

            if (!isSettled && offer.canDecline)
              _DeclineButton(
                  responding: responding,
                  onTap: () => onRespond('DECLINE')),

            if (isSettled)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isExpired
                        ? 'This offer has expired.'
                        : offer.status == 'ACCEPTED'
                            ? 'You accepted this request.'
                            : 'You declined this request.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: _kNeutral,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// URGENCY BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _UrgencyBanner extends StatelessWidget {
  const _UrgencyBanner({required this.offer, required this.isExpired});
  final StandbyOfferDetail offer;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final bgColor = isExpired
        ? const Color(0xFFF0F0F0)
        : offer.urgency == 'CRITICAL_2H'
            ? const Color(0xFFFFF0F0)
            : const Color(0xFFFFF8F0);
    final borderColor = isExpired
        ? const Color(0xFFDDDDDD)
        : offer.urgency == 'CRITICAL_2H'
            ? _kPrimary.withAlpha(80)
            : const Color(0xFFCC7722).withAlpha(80);
    final iconColor = isExpired
        ? _kNeutral
        : offer.urgency == 'CRITICAL_2H'
            ? _kPrimary
            : const Color(0xFFCC7722);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isExpired
                ? Icons.timer_off_rounded
                : Icons.emergency_rounded,
            color: iconColor,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired
                      ? 'Offer Expired'
                      : 'You Are the Backup Donor',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'This standby offer is no longer active.'
                      : 'The primary donor couldn\'t help. '
                          'Your response is urgently needed.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: _kNeutral,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTDOWN TIMER
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownTimer extends StatefulWidget {
  const _CountdownTimer({required this.offer});
  final StandbyOfferDetail offer;

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _remaining = widget.offer.timeRemaining;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining.inSeconds > 0
            ? Duration(seconds: _remaining.inSeconds - 1)
            : Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final isLow = _remaining.inSeconds < 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isLow
            ? const Color(0xFFFFF0F0)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLow ? _kPrimary.withAlpha(60) : const Color(0xFFE0DCDC),
        ),
      ),
      child: Column(
        children: [
          Text(
            '${_remaining.inHours > 0 ? '${_remaining.inHours}h ' : ''}$minutes:$seconds',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isLow ? _kPrimary : _kSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Time remaining to respond',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: isLow ? _kPrimary : _kNeutral,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'ACCEPTED' => ('✓ Accepted', const Color(0xFF1A7A3F)),
      'DECLINED' => ('✗ Declined', _kNeutral),
      _ => ('Expired', _kNeutral),
    };
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _kSecondary,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EAEA)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: _kNeutral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: _kSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
// ─────────────────────────────────────────────────────────────────────────────

class _AcceptButton extends StatelessWidget {
  const _AcceptButton(
      {required this.responding, required this.onTap});
  final bool responding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          icon: responding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.volunteer_activism_rounded, size: 18),
          label: Text(
            responding ? 'Confirming…' : 'Accept & Help',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          onPressed: responding ? null : onTap,
        ),
      ),
    );
  }
}

class _DeclineButton extends StatelessWidget {
  const _DeclineButton(
      {required this.responding, required this.onTap});
  final bool responding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDDD0D0)),
          shape: const StadiumBorder(),
        ),
        onPressed: responding ? null : onTap,
        child: const Text(
          'Decline',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _kNeutral,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON & ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _Bone(h: 100, r: 18),
        const SizedBox(height: 12),
        _Bone(h: 80, r: 16),
        const SizedBox(height: 12),
        _Bone(h: 160, r: 16),
        const SizedBox(height: 12),
        _Bone(h: 80, r: 16),
      ]),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.h, required this.r});
  final double h;
  final double r;
  @override
  Widget build(BuildContext context) => Container(
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFEEE8E8),
          borderRadius: BorderRadius.circular(r),
        ),
      );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFDDD0D0)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: _kNeutral)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder()),
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(fontFamily: 'Inter')),
            ),
          ],
        ),
      ),
    );
  }
}

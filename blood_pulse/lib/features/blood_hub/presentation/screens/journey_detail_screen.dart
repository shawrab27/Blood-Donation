// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';
import '../widgets/journey_actions.dart';
import '../widgets/journey_tracker.dart';



// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kTertiary = Color(0xFF0D68AA);
const Color _kNeutral = Color(0xFF8E7D7F);
const String _kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

Color _statusColor(String status) {
  switch (status) {
    case 'ACCEPTED':
      return _kTertiary;
    case 'ON_THE_WAY':
      return const Color(0xFFCC7722);
    case 'ARRIVED':
      return const Color(0xFF1A7A3F);
    case 'DONATED':
      return const Color(0xFF1A7A3F);
    default:
      return _kNeutral;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'ACCEPTED':
      return 'Donor Accepted';
    case 'ON_THE_WAY':
      return 'On the Way';
    case 'ARRIVED':
      return 'Arrived at Hospital';
    case 'DONATED':
      return '✓ Donation Complete';
    case 'CANCELLED':
      return 'Cancelled';
    case 'FAILED':
      return 'Not Fulfilled';
    default:
      return status;
  }
}

String _urgencyLabel(String u) {
  switch (u) {
    case 'CRITICAL_2H':
      return 'Critical · 2 h';
    case 'URGENT_6H':
      return 'Urgent · 6 h';
    case 'TODAY_24H':
      return 'Today · 24 h';
    case 'SCHEDULED':
      return 'Scheduled';
    default:
      return u;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOURNEY DETAIL SCREEN  (/journeys/:id)
// ─────────────────────────────────────────────────────────────────────────────

class JourneyDetailScreen extends ConsumerStatefulWidget {
  const JourneyDetailScreen({super.key, required this.journeyId});

  final int journeyId;

  @override
  ConsumerState<JourneyDetailScreen> createState() =>
      _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen> {
  Timer? _pollTimer;
  bool _isTracking = false;


  @override
  void initState() {
    super.initState();
    // Poll every 15 s for live status + location updates
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(journeyDetailProvider(widget.journeyId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _showIssueSheet(JourneyDetail journey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DonationIssueSheet(journeyId: journey.id),
    );
  }

  Future<void> _cancelJourney(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Journey?',
            style: TextStyle(fontFamily: 'Georgia')),
        content: const Text(
          'The donor will be notified and the request re-opened for new donors.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => ctx.pop(true),
              child:
                  const Text('Cancel', style: TextStyle(color: _kPrimary))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(bloodHubApiServiceProvider)
          .updateJourneyStatus(id, 'CANCELLED');
      if (mounted) ref.invalidate(journeyDetailProvider(id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: _kPrimary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncJourney = ref.watch(journeyDetailProvider(widget.journeyId));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _kSecondary),
        title: const Text(
          'Journey',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            color: _kSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Role badge
          asyncJourney.whenData((j) {
            final label = j.isRequester ? 'Requester' : 'Donor';
            final color = j.isRequester ? _kPrimary : _kTertiary;
            return Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                border: Border.all(color: color.withAlpha(60)),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            );
          }).valueOrNull ??
              const SizedBox.shrink(),
        ],
      ),
      body: SafeArea(
        child: asyncJourney.when(
          loading: () => const _SkeletonLoader(),
          error: (e, _) => _ErrorRetry(
            message: '$e',
            onRetry: () =>
                ref.invalidate(journeyDetailProvider(widget.journeyId)),
          ),
          data: (journey) => Column(
            children: [
              if (journey.isDonor && journey.status != 'COMPLETED' && journey.status != 'CANCELLED' && journey.status != 'FAILED')
                JourneyLiveTracker(
                  journeyId: widget.journeyId,
                  isTracking: _isTracking || journey.status == 'ON_THE_WAY',
                  onStopTracking: () {
                    setState(() => _isTracking = false);
                  },
                ),
              Expanded(
                child: _JourneyBody(
                  journey: journey,
                  onReport: () => _showIssueSheet(journey),
                  onCancel: () => _cancelJourney(journey.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────────────────────────────────────

class _JourneyBody extends ConsumerWidget {
  const _JourneyBody({
    required this.journey,
    required this.onReport,
    required this.onCancel,
  });

  final JourneyDetail journey;
  final VoidCallback onReport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveCenterWrapper(
      maxWidth: 560,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _StatusBanner(journey: journey)),
          SliverToBoxAdapter(child: _LiveMap(journey: journey)),
          SliverToBoxAdapter(child: _ProgressStepper(journey: journey)),
          // Role-specific info cards
          if (journey.isRequester)
            SliverToBoxAdapter(child: _RequesterInfoCard(journey: journey, onRefresh: () => ref.invalidate(journeyDetailProvider(journey.id))))
          else if (journey.isDonor)
            SliverToBoxAdapter(child: _DonorInfoCard(journey: journey, onRefresh: () => ref.invalidate(journeyDetailProvider(journey.id))))
          else
            SliverToBoxAdapter(child: _GenericInfoCard(journey: journey)),
          SliverToBoxAdapter(
            child: _ActionRow(
              journey: journey,
              onReport: onReport,
              onCancel: onCancel,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.journey});
  final JourneyDetail journey;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(journey.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.local_hospital_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(journey.status),
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (journey.etaMinutes != null)
                  Text(
                    'ETA ~${journey.etaMinutes} min'
                    '${journey.distanceKm != null ? ' · ${journey.distanceKm!.toStringAsFixed(1)} km' : ''}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: _kNeutral,
                    ),
                  ),
              ],
            ),
          ),
          // Blood group badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              journey.bloodGroup,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE MAP — role-aware markers
// ─────────────────────────────────────────────────────────────────────────────

class _LiveMap extends StatelessWidget {
  const _LiveMap({required this.journey});
  final JourneyDetail journey;

  @override
  Widget build(BuildContext context) {
    // Determine which pins to show based on viewer role
    LatLng? focusPin;
    LatLng? secondaryPin;

    if (journey.isRequester) {
      // Requester watches donor moving toward hospital
      if (journey.donorLat != null && journey.donorLng != null) {
        focusPin = LatLng(journey.donorLat!, journey.donorLng!);
      }
      if (journey.destLat != null && journey.destLng != null) {
        secondaryPin = LatLng(journey.destLat!, journey.destLng!);
      }
    } else if (journey.isDonor) {
      // Donor sees destination (hospital) as primary
      if (journey.destLat != null && journey.destLng != null) {
        focusPin = LatLng(journey.destLat!, journey.destLng!);
      }
      // Also show requester's location if they opted-in
      if (journey.requesterLat != null && journey.requesterLng != null) {
        secondaryPin =
            LatLng(journey.requesterLat!, journey.requesterLng!);
      }
    }

    if (!journey.isActive || focusPin == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0DCDC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FlutterMap(
          options: MapOptions(initialCenter: focusPin, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: _kTileUrl,
              userAgentPackageName: 'com.bloodpulse.app',
            ),
            MarkerLayer(
              markers: [
                // Primary marker (donor for requester / hospital for donor)
                Marker(
                  point: focusPin,
                  width: 40,
                  height: 40,
                  child: _MapPin(
                    icon: journey.isRequester
                        ? Icons.person_pin_circle_rounded
                        : Icons.local_hospital_rounded,
                    color: journey.isRequester ? _kTertiary : _kPrimary,
                    label: journey.isRequester ? 'Donor' : 'Hospital',
                  ),
                ),
                // Secondary marker
                if (secondaryPin != null)
                  Marker(
                    point: secondaryPin,
                    width: 40,
                    height: 40,
                    child: _MapPin(
                      icon: journey.isRequester
                          ? Icons.local_hospital_rounded
                          : Icons.person_pin_rounded,
                      color: journey.isRequester
                          ? _kPrimary
                          : const Color(0xFF7B61FF),
                      label: journey.isRequester ? 'Hospital' : 'Requester',
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 8,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4-STEP PROGRESS STEPPER
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.journey});
  final JourneyDetail journey;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE8E8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(journey.steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done = stepIdx + 1 < journey.steps.length &&
                journey.steps[stepIdx + 1].isComplete;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Container(
                  height: 2,
                  color: done ? _kPrimary : const Color(0xFFE0DCDC),
                ),
              ),
            );
          }
          final step = journey.steps[i ~/ 2];
          final prevDone = i == 0 || journey.steps[(i ~/ 2) - 1].isComplete;
          final isActive = !step.isComplete && prevDone;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.isComplete
                      ? _kPrimary
                      : isActive
                          ? _kPrimary.withAlpha(25)
                          : const Color(0xFFEEE8E8),
                  border: Border.all(
                    color: step.isComplete || isActive
                        ? _kPrimary
                        : const Color(0xFFDDD0D0),
                    width: 1.5,
                  ),
                ),
                child: step.isComplete
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : isActive
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _kPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: step.isComplete || isActive
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: step.isComplete || isActive
                        ? _kPrimary
                        : _kNeutral,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE-SPECIFIC INFO CARDS
// ─────────────────────────────────────────────────────────────────────────────

/// Requester sees: donor details + request summary
class _RequesterInfoCard extends ConsumerWidget {
  const _RequesterInfoCard({required this.journey, required this.onRefresh});
  final JourneyDetail journey;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _InfoCard(
      title: 'Your Donor',
      titleIcon: Icons.volunteer_activism_rounded,
      titleColor: _kTertiary,
      rows: [
        _InfoRow('Donor', journey.donorName),
        _InfoRow(
          'Contact',
          journey.donorContact.isNotEmpty
              ? journey.donorContact
              : 'Revealed after donor arrives',
          highlight: journey.donorContact.isNotEmpty,
        ),
        const _InfoDivider(),
        _InfoRow('Patient', journey.patientName),
        _InfoRow('Hospital', journey.hospitalName),
        _InfoRow('Blood', '${journey.bloodGroup} · ${journey.component}'),
        _InfoRow('Units', '${journey.unitsNeeded}'),
        _InfoRow('Urgency', _urgencyLabel(journey.urgency)),
      ],
    ),
    JourneyDonorActions(
      journeyId: journey.id,
      status: journey.status,
      onRefresh: onRefresh,
      onCancel: () {
          // TODO cancel
      },
    ),
    ],
    );
  }
}

/// Donor sees: patient + hospital details + requester contact
class _DonorInfoCard extends ConsumerWidget {
  const _DonorInfoCard({required this.journey, required this.onRefresh});
  final JourneyDetail journey;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _InfoCard(
      title: 'Your Mission',
      titleIcon: Icons.bloodtype_rounded,
      titleColor: _kPrimary,
      rows: [
        _InfoRow('Patient', journey.patientName),
        _InfoRow('Hospital', journey.hospitalName),
        _InfoRow(
          'Requester',
          journey.requesterContact.isNotEmpty
              ? journey.requesterContact
              : 'Revealed after you accept',
          highlight: journey.requesterContact.isNotEmpty,
        ),
        const _InfoDivider(),
        _InfoRow('Blood', '${journey.bloodGroup} · ${journey.component}'),
        _InfoRow('Units', '${journey.unitsNeeded}'),
        _InfoRow('Urgency', _urgencyLabel(journey.urgency)),
      ],
    ),
    JourneyDonorActions(
      journeyId: journey.id,
      status: journey.status,
      onRefresh: onRefresh,
      onCancel: () {
          // TODO cancel
      },
    ),
    ],
    );
  }
}

/// Fallback when role is unknown
class _GenericInfoCard extends StatelessWidget {
  const _GenericInfoCard({required this.journey});
  final JourneyDetail journey;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Journey Details',
      titleIcon: Icons.info_outline_rounded,
      titleColor: _kNeutral,
      rows: [
        _InfoRow('Blood', '${journey.bloodGroup} · ${journey.component}'),
        _InfoRow('Units', '${journey.unitsNeeded}'),
        _InfoRow('Urgency', _urgencyLabel(journey.urgency)),
        _InfoRow('Hospital', journey.hospitalName),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED INFO CARD SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.titleIcon,
    required this.titleColor,
    required this.rows,
  });

  final String title;
  final IconData titleIcon;
  final Color titleColor;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(titleIcon, color: titleColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EAEA)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
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
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: highlight ? _kPrimary : _kSecondary,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, color: Color(0xFFF0EAEA)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION ROW
// ─────────────────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.journey,
    required this.onReport,
    required this.onCancel,
  });

  final JourneyDetail journey;
  final VoidCallback onReport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (!journey.isActive) return const SizedBox.shrink();
    final showReport = journey.canReport;
    final showCancel = journey.canCancel;
    if (!showReport && !showCancel) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          if (showReport)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kPrimary),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.report_outlined,
                    color: _kPrimary, size: 16),
                label: const Text(
                  'Report Issue',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: _kPrimary,
                    fontSize: 13,
                  ),
                ),
                onPressed: onReport,
              ),
            ),
          if (showReport && showCancel) const SizedBox(width: 8),
          if (showCancel)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDD0D0)),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.cancel_outlined,
                    color: _kNeutral, size: 16),
                label: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: _kNeutral,
                    fontSize: 13,
                  ),
                ),
                onPressed: onCancel,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DONATION ISSUE BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DonationIssueSheet extends ConsumerStatefulWidget {
  const _DonationIssueSheet({required this.journeyId});
  final int journeyId;

  @override
  ConsumerState<_DonationIssueSheet> createState() =>
      _DonationIssueSheetState();
}

class _DonationIssueSheetState
    extends ConsumerState<_DonationIssueSheet> {
  String _issueType = 'MEDICAL_REJECTION';
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  static const _issues = [
    (
      'MEDICAL_REJECTION',
      'Medical Rejection',
      'Donor medically unfit at hospital — 90-day deferral applied'
    ),
    (
      'DONOR_NO_SHOW',
      'Donor No-Show',
      'Donor did not arrive within expected time'
    ),
    (
      'LOGISTICS',
      'Logistics Issue',
      'Transport or scheduling problem — request will re-open'
    ),
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(bloodHubApiServiceProvider)
          .reportDonationIssue(widget.journeyId, _issueType, _noteCtrl.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        ref.invalidate(journeyDetailProvider(widget.journeyId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Issue reported — standby donor activated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: _kPrimary),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDD0D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report Donation Issue',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _kSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'The backup standby donor will be notified automatically.',
            style: TextStyle(
                fontFamily: 'Inter', fontSize: 12, color: _kNeutral),
          ),
          const SizedBox(height: 16),
          ..._issues.map((issue) {
            final (value, label, sub) = issue;
            final selected = _issueType == value;
            return GestureDetector(
              onTap: () => setState(() => _issueType = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFEE9EB)
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _kPrimary : const Color(0xFFE8DADA),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? _kPrimary : _kNeutral,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? _kPrimary : _kSecondary,
                            ),
                          ),
                          Text(
                            sub,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: _kNeutral),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFFBBAAAA)),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE8DADA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE8DADA)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Submit & Activate Standby',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON & ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Bone(height: 80, radius: 18),
          const SizedBox(height: 12),
          _Bone(height: 200, radius: 16),
          const SizedBox(height: 12),
          _Bone(height: 64, radius: 16),
          const SizedBox(height: 12),
          _Bone(height: 180, radius: 16),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.height, required this.radius});
  final double height;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEE8E8),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
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
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFFDDD0D0)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 13, color: _kNeutral),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
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

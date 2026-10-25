// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/deep_link_resolver.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../data/blood_hub_api_service.dart';

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kTertiary = Color(0xFF0D68AA);
const Color _kNeutral = Color(0xFF8E7D7F);

// ─────────────────────────────────────────────────────────────────────────────
// REQUESTER ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class JourneyRequesterActions extends ConsumerStatefulWidget {
  final JourneyDetail journey;
  final VoidCallback onRefresh;
  final VoidCallback onIssueReport;
  final VoidCallback onCancel;

  const JourneyRequesterActions({
    super.key,
    required this.journey,
    required this.onRefresh,
    required this.onIssueReport,
    required this.onCancel,
  });

  @override
  ConsumerState<JourneyRequesterActions> createState() => _JourneyRequesterActionsState();
}

class _JourneyRequesterActionsState extends ConsumerState<JourneyRequesterActions> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await ref.read(bloodHubApiServiceProvider).updateJourneyStatus(widget.journey.id, newStatus);
      widget.onRefresh();
      if (newStatus == 'COMPLETED' && mounted) {
        context.push('/blood-hub/thanks', extra: {
          'matchId': widget.journey.id,
          'donorName': widget.journey.donorName.isNotEmpty ? widget.journey.donorName : 'Donor',
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final status = journey.status;

    // 1. COMPLETED state
    if (status == 'COMPLETED') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: PressableScale(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A7A3F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            icon: const Icon(Icons.card_giftcard_rounded, size: 18),
            label: const Text(
              'View Thank You Letter',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              context.push('/blood-hub/thanks', extra: {
                'matchId': journey.id,
                'donorName': journey.donorName.isNotEmpty ? journey.donorName : 'Donor',
              });
            },
          )),
        ),
      );
    }

    // 2. STANDBY_SEARCHING state
    if (status == 'STANDBY_SEARCHING') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB74D)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppLoader.small(color: Color(0xFFE65100)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Finding a replacement standby donor...',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'We are automatically escalating the search radius (5km → 25km → 100km → 1000km) to find the nearest eligible donor.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5D4037)),
            ),
            const SizedBox(height: 12),
            PressableScale(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE65100)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: widget.onCancel,
              child: const Text('Cancel Request', style: TextStyle(color: Color(0xFFE65100))),
            )),
          ],
        ),
      );
    }

    // 3. OPEN state
    if (status == 'OPEN') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEE8E8)),
        ),
        child: Column(
          children: [
            const Text(
              'Your requisition is active. Searching for nearby eligible donors.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kSecondary),
            ),
            const SizedBox(height: 12),
            PressableScale(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: widget.onCancel,
              child: const Text('Cancel Request', style: TextStyle(color: _kPrimary)),
            )),
          ],
        ),
      );
    }

    // 4. DONATED state -> Confirm Receipt button
    final isDonated = status == 'DONATED';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          if (isDonated) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.verified_rounded, size: 18),
                onPressed: _loading ? null : () => _updateStatus('COMPLETED'),
                label: _loading
                    ? const AppLoader()
                    : const Text(
                        'Confirm Donation Received',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              )),
            ),
            const SizedBox(height: 12),
          ],

          // Part 2 Requester Action Buttons: Open Chat, Track Donor, Call Donor
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Open Chat
              PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTertiary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Open Chat', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  context.push(
                    '/chat',
                    extra: {
                      'chatRecipientName': journey.donorName.isNotEmpty ? journey.donorName : 'Donor',
                      'bloodGroup': journey.bloodGroup,
                      'chatRoomId': journey.chatRoomId ?? 'chat_${journey.id}',
                      'recipientId': journey.donorName,
                    },
                  );
                },
              )),

              // Track Donor
              PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC7722),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.navigation_outlined, size: 16),
                label: const Text('Track Donor', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  context.push(
                    '/blood-hub/tracking',
                    extra: {
                      'requestId': journey.requestId?.toString() ?? journey.id.toString(),
                      'matchId': journey.id,
                      'patientName': journey.patientName,
                      'hospitalName': journey.hospitalName,
                      'bloodGroup': journey.bloodGroup,
                      'donorName': journey.donorName,
                      'donorPhone': journey.donorContact,
                      'isDonorView': false,
                      'chatRoomId': journey.chatRoomId ?? 'chat_${journey.id}',
                    },
                  );
                },
              )),

              // Call Donor (only once ACCEPTED and phone unmasked)
              if (journey.donorContact.isNotEmpty)
                PressableScale(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1A7A3F), width: 1.5),
                    foregroundColor: const Color(0xFF1A7A3F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: const Text('Call Donor', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => DeepLinkResolver.instance.makePhoneCall(journey.donorContact),
                )),
            ],
          ),

          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              PressableScale(child: TextButton.icon(
                onPressed: widget.onIssueReport,
                icon: const Icon(Icons.report_problem_outlined, color: _kPrimary, size: 16),
                label: const Text('Report Issue', style: TextStyle(color: _kPrimary, fontSize: 12, fontFamily: 'Inter')),
              )),
              PressableScale(child: TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.cancel_outlined, color: _kNeutral, size: 16),
                label: const Text('Cancel Request', style: TextStyle(color: _kNeutral, fontSize: 12, fontFamily: 'Inter')),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DONOR ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class JourneyDonorActions extends ConsumerStatefulWidget {
  final JourneyDetail journey;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  const JourneyDonorActions({
    super.key,
    required this.journey,
    required this.onRefresh,
    required this.onCancel,
  });

  @override
  ConsumerState<JourneyDonorActions> createState() => _JourneyDonorActionsState();
}

class _JourneyDonorActionsState extends ConsumerState<JourneyDonorActions> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await ref.read(bloodHubApiServiceProvider).updateJourneyStatus(widget.journey.id, newStatus);
      widget.onRefresh();
      if (newStatus == 'DONATED' && mounted) {
        context.push('/blood-hub/thanks', extra: {
          'matchId': widget.journey.id,
          'donorName': widget.journey.donorName.isNotEmpty ? widget.journey.donorName : 'Donor',
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final status = journey.status;

    // 1. COMPLETED state
    if (status == 'COMPLETED' || status == 'DONATED') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: PressableScale(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A7A3F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            icon: const Icon(Icons.card_giftcard_rounded, size: 18),
            label: const Text(
              'View Thank You Letter',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              context.push('/blood-hub/thanks', extra: {
                'matchId': journey.id,
                'donorName': journey.donorName.isNotEmpty ? journey.donorName : 'Donor',
              });
            },
          )),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          // Primary Progress Button based on current state
          if (status == 'ACCEPTED')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.directions_run_rounded, size: 20),
                onPressed: _loading ? null : () => _updateStatus('ON_THE_WAY'),
                label: _loading
                    ? const AppLoader()
                    : const Text(
                        "Start Going (Start Tracking)",
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              )),
            )
          else if (status == 'ON_THE_WAY')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC7722),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.local_hospital_rounded, size: 20),
                onPressed: _loading ? null : () => _updateStatus('ARRIVED'),
                label: _loading
                    ? const AppLoader()
                    : const Text(
                        "Mark Arrived (At Hospital)",
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              )),
            )
          else if (status == 'ARRIVED')
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A7A3F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                onPressed: _loading ? null : () => _updateStatus('DONATED'),
                label: _loading
                    ? const AppLoader()
                    : const Text(
                        "Mark Donated (Completed Donation)",
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              )),
            ),

          const SizedBox(height: 12),

          // Secondary Action Buttons: Open Chat, Call Requester, Can't Donate
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Open Chat
              PressableScale(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTertiary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Open Chat', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  context.push(
                    '/chat',
                    extra: {
                      'chatRecipientName': journey.patientName.isNotEmpty ? journey.patientName : 'Requester',
                      'bloodGroup': journey.bloodGroup,
                      'chatRoomId': journey.chatRoomId ?? 'chat_${journey.id}',
                      'recipientId': journey.patientName,
                    },
                  );
                },
              )),

              // Call Requester (only once ACCEPTED and phone unmasked)
              if (journey.requesterContact.isNotEmpty)
                PressableScale(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1A7A3F), width: 1.5),
                    foregroundColor: const Color(0xFF1A7A3F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: const Text('Call Requester', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => DeepLinkResolver.instance.makePhoneCall(journey.requesterContact),
                )),
            ],
          ),

          if (status == 'ACCEPTED' || status == 'ON_THE_WAY') ...[
            const SizedBox(height: 8),
            PressableScale(child: TextButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.cancel_outlined, color: Colors.black54, size: 16),
              label: const Text(
                "I Can't Donate (Cancel & Activate Standby)",
                style: TextStyle(color: Colors.black54, fontSize: 12, fontFamily: 'Inter'),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

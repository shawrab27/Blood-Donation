// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';
import '../../../../core/domain/entities/national_emergency.dart';

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kTertiary = Color(0xFF0D68AA);
const Color _kNeutral = Color(0xFF8E7D7F);

class NationalEmergencyScreen extends ConsumerStatefulWidget {
  const NationalEmergencyScreen({super.key});

  @override
  ConsumerState<NationalEmergencyScreen> createState() => _NationalEmergencyScreenState();
}

class _NationalEmergencyScreenState extends ConsumerState<NationalEmergencyScreen> {
  @override
  Widget build(BuildContext context) {
    final asyncEvent = ref.watch(activeNationalEmergencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _kSecondary),
        title: const Text(
          'National Overview',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kSecondary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeNationalEmergencyProvider);
          ref.invalidate(myDisasterPledgeProvider);
        },
        child: asyncEvent.when(
          data: (event) {
            if (event == null || !event.isActive) {
              return const _FrozenState();
            }
            return _NationalBody(event: event);
          },
          loading: () => const _Skeleton(),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _FrozenState extends StatelessWidget {
  const _FrozenState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 64, color: _kNeutral),
            const SizedBox(height: 24),
            const Text(
              'No emergency right now',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "You'll be alerted here when a national emergency is declared.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: _kNeutral,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Join Disaster Response', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NationalBody extends ConsumerWidget {
  const _NationalBody({required this.event});
  final NationalEmergencyEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int totalNeeded = 0;
    int totalCollected = 0;
    for (var p in event.points) {
      totalNeeded += p.targetBags;
      totalCollected += p.collectedBags;
    }
    final pct = totalNeeded == 0 ? 0.0 : (totalCollected / totalNeeded).clamp(0.0, 1.0);
    final myPledgeAsync = ref.watch(myDisasterPledgeProvider);

    return ResponsiveCenterWrapper(
      maxWidth: 560,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _kTertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: _kTertiary, size: 14),
                          const SizedBox(width: 4),
                          Text('Verified by BloodPulse Admin', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _kTertiary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  Text(
                    event.titleEn,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: _kPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.descriptionEn,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: _kSecondary),
                  ),
                  const SizedBox(height: 24),
                  const Text('Disaster Progress', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: _kSecondary)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: pct,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  const SizedBox(height: 8),
                  Text('Collected Bags $totalCollected/$totalNeeded', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _kNeutral, fontWeight: FontWeight.bold)),
                  
                  const SizedBox(height: 24),
                  const Text('Official Instructions', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: _kSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFBB8B8))),
                    child: Text(
                      event.instructionsEn.isNotEmpty ? event.instructionsEn : 'Follow official guidelines. Wait for verification before donating.',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Note: You must have a ${event.donationIntervalDays}-day gap from your last donation to be eligible.', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: _kNeutral)),
                ],
              ),
            ),
          ),
          myPledgeAsync.when(
            data: (pledge) {
              if (pledge == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _kPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kPrimary.withOpacity(0.3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Pledge', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: _kPrimary)),
                      const SizedBox(height: 8),
                      Text('Point: ${pledge.pointName}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kSecondary)),
                      if (pledge.slot != null) Text('Time: ${pledge.slot!.timeRange}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kSecondary)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Text('Code: ${pledge.pledgeCode}', style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2, color: _kPrimary)),
                      )
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Response Points', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: _kSecondary)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final point = event.points[index];
                return _PointCard(point: point);
              },
              childCount: event.points.length,
            ),
          ),
          const SliverToBoxAdapter(child: _HotlinesCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for sticky button
        ],
      ),
    );
  }
}

class _PointCard extends ConsumerWidget {
  const _PointCard({required this.point});
  final DisasterResponsePoint point;

  void _showPledgeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PledgeSheet(point: point),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = point.status == 'COVERED' ? const Color(0xFF1A7A3F) : _kPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: _kSecondary)),
                    Text(point.district, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kNeutral)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
                child: Text(point.status, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (point.urgentBloodGroups.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: point.urgentBloodGroups.map((bg) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(bg, style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
              )).toList(),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.people, size: 14, color: _kTertiary),
              const SizedBox(width: 4),
              Text('${point.donorsOnTheWay} donors on the way', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _kTertiary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          if (point.status == 'COVERED')
            const Center(child: Text('Fully covered, thank you', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1A7A3F), fontWeight: FontWeight.bold)))
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: point.slots.isEmpty ? null : () => _showPledgeSheet(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Pledge to Donate (Select Slot)', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PledgeSheet extends ConsumerStatefulWidget {
  const _PledgeSheet({required this.point});
  final DisasterResponsePoint point;

  @override
  ConsumerState<_PledgeSheet> createState() => _PledgeSheetState();
}

class _PledgeSheetState extends ConsumerState<_PledgeSheet> {
  int? _selectedSlotId;
  bool _agreed = false;
  bool _loading = false;
  String? _successCode;

  Future<void> _submitPledge() async {
    if (_selectedSlotId == null || !_agreed) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(bloodHubApiServiceProvider).pledgeToDonate(_selectedSlotId!);
      ref.invalidate(myDisasterPledgeProvider);
      ref.invalidate(activeNationalEmergencyProvider);
      if (mounted) {
        setState(() {
          _loading = false;
          _successCode = res['pledge_code'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_successCode != null) {
      return Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF1A7A3F), size: 64),
            const SizedBox(height: 16),
            const Text('Pledge Confirmed!', style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: _kSecondary)),
            const SizedBox(height: 16),
            const Text('Show this code when you arrive:', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _kNeutral)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(_successCode!, style: const TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: _kPrimary)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: _kSecondary, foregroundColor: Colors.white, shape: const StadiumBorder()),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Select Slot for ${widget.point.name}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: _kSecondary)),
          const SizedBox(height: 16),
          ...widget.point.slots.map((slot) {
            final isFull = slot.pledged >= slot.capacity;
            return RadioListTile<int>(
              title: Text(slot.timeRange, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              subtitle: Text(isFull ? 'Slot Full' : '${slot.capacity - slot.pledged} spots remaining'),
              value: slot.id,
              groupValue: _selectedSlotId,
              onChanged: isFull ? null : (val) => setState(() => _selectedSlotId = val),
              activeColor: _kPrimary,
            );
          }),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Eligibility Checklist', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: _kSecondary)),
          const Text('DRAFT: to be reviewed with a doctor', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: _kPrimary, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agreed,
            onChanged: (val) => setState(() => _agreed = val ?? false),
            title: const Text('I am 18-60 years old, weigh > 50kg, feel well, have no fever/cough, and have not donated in the last 120 days.', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
            activeColor: _kPrimary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedSlotId != null && _agreed && !_loading) ? _submitPledge : null,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirm Pledge', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotlinesCard extends StatelessWidget {
  const _HotlinesCard();

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kSecondary, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Text('Emergency Hotlines', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HotlineButton(icon: Icons.local_police, label: '999', onTap: () => _call('999')),
              _HotlineButton(icon: Icons.local_fire_department, label: '16163', onTap: () => _call('16163')),
            ],
          )
        ],
      ),
    );
  }
}

class _HotlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HotlineButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: _kPrimary));
  }
}

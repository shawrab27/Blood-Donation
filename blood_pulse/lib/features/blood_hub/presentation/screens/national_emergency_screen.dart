// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';
import '../../../../core/domain/entities/national_emergency.dart';
import '../../../../core/access/access_guard.dart';
import '../../../../services/api_client.dart';
import '../widgets/request_units_progress_card.dart';

const Color _kPrimary = Color(0xFFC30121);
const Color _kDarkRed = Color(0xFF850014);
const Color _kSecondary = Color(0xFF24191A);
const Color _kTertiary = Color(0xFF004B7E);
const Color _kNeutral = Color(0xFF5C3F3D);

/// National Emergency Screen:
/// Lists verified critical emergency requests across all 64 districts in Bangladesh.
/// Provides blood group & division filters, disaster alert banners, and a clear "I Can Donate" action.
/// Guests have limited, privacy-safe view (zero raw phone, email, or exact coordinates).
class NationalEmergencyScreen extends ConsumerStatefulWidget {
  const NationalEmergencyScreen({super.key});

  @override
  ConsumerState<NationalEmergencyScreen> createState() => _NationalEmergencyScreenState();
}

class _NationalEmergencyScreenState extends ConsumerState<NationalEmergencyScreen> {
  String _selectedBloodGroup = 'All';
  String _selectedDivision = 'All';

  final List<String> _bloodGroups = const [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  final List<String> _divisions = const [
    'All',
    'Dhaka',
    'Chattogram',
    'Rajshahi',
    'Khulna',
    'Barishal',
    'Sylhet',
    'Rangpur',
    'Mymensingh',
  ];

  NationalEmergencyFilterState get _currentFilter => NationalEmergencyFilterState(
        bloodGroup: _selectedBloodGroup,
        division: _selectedDivision,
      );

  void _handleDonateTap(NationalEmergencyRequestItem request) {
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      _showGuestLoginDialog(context);
    } else {
      _showDonateConfirmationModal(context, request);
    }
  }

  void _showGuestLoginDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock_outline_rounded, color: _kPrimary, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sign In Required',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _kSecondary,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'To accept an emergency blood requisition and connect with the hospital attendant, please log in or create a donor profile.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: _kNeutral, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Sign In to Donate', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDonateConfirmationModal(BuildContext context, NationalEmergencyRequestItem request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DonateConfirmationSheet(
        request: request,
        onConfirmed: () async {
          Navigator.pop(ctx);
          await _submitDonationPledge(request);
        },
      ),
    );
  }

  Future<void> _submitDonationPledge(NationalEmergencyRequestItem request) async {
    final api = ref.read(bloodHubApiServiceProvider);
    try {
      await api.acceptBloodRequest(
        request.id,
        supportStatus: 'CAN_SUPPORT',
        unitsPledged: 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pledge submitted for ${request.patientName} at ${request.hospitalName}!',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: const Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(nationalEmergencyRequestsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Failed to submit donation response: $e',
            style: const TextStyle(fontFamily: 'Inter'),
          ),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncDisaster = ref.watch(activeNationalEmergencyProvider);
    final asyncRequests = ref.watch(nationalEmergencyRequestsProvider(_currentFilter));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 160,
        leading: TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/blood-hub');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18, color: _kSecondary),
          label: const Text(
            'Exit Emergency',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: _kSecondary,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 12),
            alignment: Alignment.centerLeft,
          ),
        ),
        title: const Text(
          'National Emergency',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kDarkRed,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEAEB),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFFFDAD6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    '64 DISTRICTS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: RefreshIndicator(
            color: _kPrimary,
            onRefresh: () async {
              ref.invalidate(activeNationalEmergencyProvider);
              ref.invalidate(nationalEmergencyRequestsProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Header notice & Filters
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Disaster Event Banner (if active disaster declared)
                        asyncDisaster.when(
                          data: (disaster) {
                            if (disaster != null && disaster.isActive) {
                              return _buildDisasterAlertBanner(disaster);
                            }
                            return const SizedBox.shrink();
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 8),

                        // Title and Scope subtitle
                        const Text(
                          'Verified Emergency Requests',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _kDarkRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Real-time verified high-priority blood requisitions from partner hospitals and validated attendants nationwide.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: Color(0xFF755E60),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Blood Group Filter
                        _buildFilterRow(
                          label: 'Blood Group',
                          items: _bloodGroups,
                          selected: _selectedBloodGroup,
                          onSelected: (val) {
                            setState(() => _selectedBloodGroup = val);
                          },
                        ),
                        const SizedBox(height: 10),

                        // Division Filter
                        _buildFilterRow(
                          label: 'Division',
                          items: _divisions,
                          selected: _selectedDivision,
                          onSelected: (val) {
                            setState(() => _selectedDivision = val);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                // Request List or Status View
                asyncRequests.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _buildEmptyState(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final req = requests[index];
                            return _EmergencyRequestCard(
                              request: req,
                              onDonateTap: () => _handleDonateTap(req),
                            );
                          },
                          childCount: requests.length,
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: AppLoader()),
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(
                    child: _buildErrorState(err.toString()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisasterAlertBanner(NationalEmergencyEvent disaster) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE9EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6BDBA), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F960017),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kDarkRed,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text(
                  'DISASTER EVENT ACTIVE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified, size: 14, color: _kTertiary),
              const SizedBox(width: 4),
              const Text(
                '2-Admin Authorized',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _kTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            disaster.titleEn,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _kDarkRed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            disaster.descriptionEn,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: _kNeutral, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (disaster.points.isNotEmpty) ...[
            const SizedBox(height: 12),
            RequestUnitsProgressCard(
              title: 'Disaster Units Progress',
              unitsReceived: disaster.points.fold<int>(0, (acc, p) => acc + p.collectedBags),
              unitsPending: 0,
              unitsNeeded: disaster.points.fold<int>(0, (acc, p) => acc + p.targetBags),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow({
    required String label,
    required List<String> items,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item == selected;
          return ChoiceChip(
            label: Text(item),
            selected: isSelected,
            onSelected: (_) => onSelected(item),
            labelStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF4A4445),
            ),
            selectedColor: _kPrimary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? _kPrimary : const Color(0xFFE4D7D7),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEFE8E8)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 52, color: Color(0xFF1B8A4E)),
            const SizedBox(height: 14),
            const Text(
              'No Emergency Requisitions',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _kSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Currently no active critical requests match $_selectedBloodGroup blood in $_selectedDivision division. All requests in this scope are fulfilled.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: Color(0xFF755E60),
                height: 1.4,
              ),
            ),
            if (_selectedBloodGroup != 'All' || _selectedDivision != 'All') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedBloodGroup = 'All';
                    _selectedDivision = 'All';
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFDAD6)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _kPrimary),
            const SizedBox(height: 12),
            const Text(
              'Could not load emergency requests',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kDarkRed,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: _kNeutral),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(nationalEmergencyRequestsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyRequestCard extends StatelessWidget {
  const _EmergencyRequestCard({
    required this.request,
    required this.onDonateTap,
  });

  final NationalEmergencyRequestItem request;
  final VoidCallback onDonateTap;

  @override
  Widget build(BuildContext context) {
    final locationText = [
      if (request.district.isNotEmpty) request.district,
      if (request.divisionName.isNotEmpty) '${request.divisionName} Division',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DADA), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Blood Group Pill + Urgency + Verified Badge
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      request.bloodGroup,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEAEB),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      request.urgency.replaceAll('_', ' '),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _kDarkRed,
                      ),
                    ),
                  ),
                ],
              ),
              if (request.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF6FF),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFC7E2FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified_rounded, size: 12, color: Color(0xFF005697)),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF005697),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Patient & Hospital Info
          Text(
            request.patientName,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _kSecondary,
            ),
          ),
          const SizedBox(height: 4),

          if (request.hospitalName.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.local_hospital_rounded, size: 15, color: _kDarkRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.hospitalName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          if (locationText.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF8E7D7F)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF5C3F3D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          // Units Needed info
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.water_drop_rounded, size: 15, color: _kPrimary),
              Text(
                '${request.unitsNeeded} unit(s) ${request.component.toLowerCase()} needed',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                ),
              ),
              if (request.unitsReceived > 0)
                Text(
                  '(${request.unitsReceived} received)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: Color(0xFF1B8A4E),
                  ),
                ),
            ],
          ),

          // Masked contact row (privacy-safe for guests & all public views)
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEFE8E8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, size: 13, color: Color(0xFF755E60)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.contactPhoneMasked.isNotEmpty
                        ? 'Attendant Contact: ${request.contactPhoneMasked}'
                        : 'Attendant Contact: Protected (PII shielded)',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF755E60),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // "I Can Donate" Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onDonateTap,
              icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
              label: const Text(
                'I Can Donate',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonateConfirmationSheet extends StatelessWidget {
  const _DonateConfirmationSheet({
    required this.request,
    required this.onConfirmed,
  });

  final NationalEmergencyRequestItem request;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D5D5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDEAEB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.crisis_alert_rounded, color: _kPrimary, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Confirm Blood Donation',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'You are responding to an urgent blood request for ${request.patientName} (${request.bloodGroup}) at ${request.hospitalName}.',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: _kNeutral, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3F3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFDAD6)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 16, color: _kPrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By accepting, your availability will be signaled to the hospital attendant and you will enter the donor tracking network.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: _kDarkRed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kNeutral,
                      side: const BorderSide(color: Color(0xFFE0D5D5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onConfirmed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Confirm & Respond', style: TextStyle(fontWeight: FontWeight.bold)),
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

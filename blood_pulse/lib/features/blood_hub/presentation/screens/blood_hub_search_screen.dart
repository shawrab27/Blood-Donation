// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/deferral_notice_card.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kSurface = Color(0xFFFFF8F7);

// OSM tile URL — single config constant per Rule 9.
const String _kTileUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

const List<String> _kBloodGroups = [
  'Any', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
];

const List<String> _kComponents = [
  'Any', 'WHOLE', 'RBC', 'PLATELETS', 'PLASMA',
];

const Map<String, List<String>> _kDivisionDistricts = {
  'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Faridpur', 'Manikganj', 'Munshiganj', 'Narsingdi', 'Gopalganj', 'Kishoreganj', 'Madaripur', 'Rajbari', 'Shariatpur'],
  'Chattogram': ['Chattogram', "Cox's Bazar", 'Cumilla', 'Feni', 'Brahmanbaria', 'Chandpur', 'Noakhali', 'Lakshmipur', 'Khagrachhari', 'Rangamati', 'Bandarban'],
  'Rajshahi': ['Rajshahi', 'Bogura', 'Pabna', 'Sirajganj', 'Naogaon', 'Natore', 'Chapai Nawabganj', 'Joypurhat'],
  'Khulna': ['Khulna', 'Jashore', 'Kushtia', 'Satkhira', 'Bagerhat', 'Chuadanga', 'Jhenaidah', 'Magura', 'Meherpur', 'Narail'],
  'Barishal': ['Barishal', 'Bhola', 'Jhalokati', 'Patuakhali', 'Pirojpur', 'Barguna'],
  'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj'],
  'Rangpur': ['Rangpur', 'Dinajpur', 'Kurigram', 'Gaibandha', 'Nilphamari', 'Panchagarh', 'Thakurgaon', 'Lalmonirhat'],
  'Mymensingh': ['Mymensingh', 'Jamalpur', 'Netrokona', 'Sherpur'],
};

// ─────────────────────────────────────────────────────────────────────────────
// BLOOD HUB SEARCH SCREEN
// ─────────────────────────────────────────────────────────────────────────────

/// Screen: /blood-hub/search
/// Donor search with blood-group chips, component filter, district selector,
/// paginated list view, fuzzed OSM map pins, and "Request All" CTA.
class BloodHubSearchScreen extends ConsumerStatefulWidget {
  const BloodHubSearchScreen({super.key});

  @override
  ConsumerState<BloodHubSearchScreen> createState() =>
      _BloodHubSearchScreenState();
}

class _BloodHubSearchScreenState extends ConsumerState<BloodHubSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final notifier = ref.read(donorSearchNotifierProvider.notifier);
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      notifier.loadMore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Filter Chip helpers ──────────────────────────────────────────────────

  Widget _bloodGroupChips() {
    final filter = ref.watch(bloodHubFilterProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _kBloodGroups.map((group) {
          final selected = (group == 'Any' && filter.bloodGroup == null) ||
              filter.bloodGroup == group;
          return GestureDetector(
            onTap: () => ref.read(bloodHubFilterProvider.notifier).update(
                  (s) => s.copyWith(
                    clearBloodGroup: group == 'Any',
                    bloodGroup: group == 'Any' ? null : group,
                  ),
                ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: selected ? _kPrimary : const Color(0xFFDDD0D0),
                ),
              ),
              child: Text(
                group,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _kSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _componentChips() {
    final filter = ref.watch(bloodHubFilterProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kComponents.map((comp) {
        final selected = (comp == 'Any' && filter.component == null) ||
            filter.component == comp;
        return GestureDetector(
          onTap: () => ref.read(bloodHubFilterProvider.notifier).update(
                (s) => s.copyWith(
                  clearComponent: comp == 'Any',
                  component: comp == 'Any' ? null : comp,
                ),
              ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0D68AA) : Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D68AA)
                    : const Color(0xFFDDD0D0),
              ),
            ),
            child: Text(
              comp,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _kSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Division / District selector ──────────────────────────────────────────

  Widget _locationRow() {
    final filter = ref.watch(bloodHubFilterProvider);
    final divisions = _kDivisionDistricts.keys.toList();
    final districts =
        filter.division != null ? _kDivisionDistricts[filter.division!] ?? [] : [];

    return Row(
      children: [
        Expanded(
          child: _DropdownField<String?>(
            hint: 'Division',
            value: filter.division,
            items: [null, ...divisions],
            labelBuilder: (v) => v ?? 'All Divisions',
            onChanged: (v) => ref.read(bloodHubFilterProvider.notifier).update(
                  (s) => s.copyWith(
                    clearDivision: v == null,
                    division: v,
                    clearDistrict: true,
                  ),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DropdownField<String?>(
            hint: 'District',
            value: filter.district,
            items: [null, ...districts],
            labelBuilder: (v) => v ?? 'All Districts',
            enabled: filter.division != null,
            onChanged: (v) => ref.read(bloodHubFilterProvider.notifier).update(
                  (s) => s.copyWith(
                    clearDistrict: v == null,
                    district: v,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  // ── "Request All" button ──────────────────────────────────────────────────

  Widget _requestAllButton(List<DonorSearchModel> donors) {
    if (donors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          onPressed: () {
            final filter = ref.read(bloodHubFilterProvider);
            context.push('/emergency/personal', extra: {
              'prefill_blood_group': filter.bloodGroup,
              'prefill_component': filter.component,
              'prefill_district': filter.district,
              'mode': 'REQUEST_ALL',
              'donor_count': donors.length,
            });
          },
          icon: const Icon(Icons.water_drop_rounded, size: 18),
          label: Text(
            'Request All ${donors.length} Donors',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Donor List ────────────────────────────────────────────────────────────

  Widget _donorList() {
    final async = ref.watch(donorSearchNotifierProvider);

    return async.when(
      loading: () => _buildSkeletonList(),
      error: (e, _) => _buildError(e.toString()),
      data: (page) {
        if (page.donors.isEmpty) return _buildEmpty();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _requestAllButton(page.donors),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${page.totalCount} donors found',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF8E7D7F),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: page.donors.length,
              itemBuilder: (_, i) => _DonorCard(donor: page.donors[i]),
            ),
            if (page.nextCursor != null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: _kPrimary)),
              ),
          ],
        );
      },
    );
  }

  // ── OSM Map View ──────────────────────────────────────────────────────────

  Widget _mapView() {
    final pinsAsync = ref.watch(donorMapPinsProvider);

    return SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(23.8103, 90.4125), // Dhaka centre
                initialZoom: 7,
                minZoom: 5,
                maxZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: _kTileUrl,
                  userAgentPackageName: 'com.bloodpulse.app',
                ),
                pinsAsync.when(
                  data: (pins) => MarkerLayer(
                    markers: pins.map((pin) {
                      return Marker(
                        point: LatLng(pin.lat, pin.lng),
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pin.isVerified
                                ? _kPrimary
                                : const Color(0xFF0D68AA),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              pin.bloodGroup.replaceAll(' ', ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const MarkerLayer(markers: []),
                  error: (_, _) => const MarkerLayer(markers: []),
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (pinsAsync.isLoading)
              const Positioned(
                top: 8,
                right: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Empty / Error / Skeleton ─────────────────────────────────────────────

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.person_search_rounded,
                size: 64, color: Color(0xFFDDD0D0)),
            SizedBox(height: 16),
            Text(
              'No eligible donors found\nfor the selected filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF8E7D7F),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: Color(0xFF8E7D7F)),
          const SizedBox(height: 12),
          Text(
            'Could not load donors.\n$message',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF8E7D7F),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                ref.read(donorSearchNotifierProvider.notifier).refresh(),
            child: const Text(
              'Retry',
              style: TextStyle(color: _kPrimary, fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: _SkeletonCard(),
        ),
      ),
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsiveCenterWrapper(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter header
            const DeferralNoticeCard(),
            // ── Filter header ──────────────────────────────────────────────
            Container(
              color: _kSurface,
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Blood Group',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8E7D7F),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _bloodGroupChips(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Blood Component',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E7D7F),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _componentChips(),
                        const SizedBox(height: 12),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8E7D7F),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _locationRow(),
                        const SizedBox(height: 12),
                        // Toggle map button
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showMap = !_showMap),
                          child: Row(
                            children: [
                              Icon(
                                _showMap
                                    ? Icons.map_rounded
                                    : Icons.map_outlined,
                                size: 16,
                                color: _kPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showMap ? 'Hide Map' : 'Show Map',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: _kPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Map (conditional) ──────────────────────────────────────────
            if (_showMap)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Padding(
                  key: const ValueKey('map'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _mapView(),
                ),
              ),

            // ── Donor list ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: _donorList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DONOR CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _DonorCard extends StatelessWidget {
  const _DonorCard({required this.donor});

  final DonorSearchModel donor;

  @override
  Widget build(BuildContext context) {
    final eligibleColor =
        donor.isEligible ? const Color(0xFF1A7A3F) : const Color(0xFF8E7D7F);
    final eligibleLabel =
        donor.isEligible ? 'Eligible' : 'Not Eligible';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Blood group badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    donor.bloodGroup,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            donor.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (donor.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified_rounded,
                                size: 14, color: Color(0xFF0D68AA)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${donor.district}, ${donor.division}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF8E7D7F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(
                          label: eligibleLabel,
                          color: eligibleColor,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          label: donor.component,
                          color: const Color(0xFF0D68AA),
                        ),
                        const SizedBox(width: 6),
                        _TrustBadge(band: donor.trustBand),
                      ],
                    ),
                  ],
                ),
              ),
              // Masked phone
              Column(
                children: [
                  Text(
                    donor.maskedPhone,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Color(0xFF8E7D7F),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.band});

  final String band;

  @override
  Widget build(BuildContext context) {
    final color = switch (band) {
      'HIGH' => const Color(0xFF1A7A3F),
      'MEDIUM' => const Color(0xFFCC7722),
      _ => const Color(0xFF8E7D7F),
    };
    return _Chip(label: band, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5EAEA),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 12, width: 120, color: const Color(0xFFF5EAEA)),
                const SizedBox(height: 8),
                Container(
                    height: 10, width: 80, color: const Color(0xFFF5F5F5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERIC DROPDOWN FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.enabled = true,
  });

  final String hint;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final void Function(T) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xFFDDD0D0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF8E7D7F),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: _kSecondary,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Color(0xFF8E7D7F)),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelBuilder(item),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

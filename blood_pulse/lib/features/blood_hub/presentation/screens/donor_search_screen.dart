// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/blood_hub_api_service.dart';
import '../widgets/donor_search/donor_search_bar.dart';
import '../widgets/donor_search/donor_filter_chips.dart';
import '../widgets/donor_search/donor_card.dart';
import '../widgets/donor_search/donor_map_view.dart';
import '../widgets/donor_search/donor_search_skeleton.dart';

/// Screen 2: Donor Search Screen conforming to Stitch UI specification.
/// Features privacy-locked search bar, interactive filter chips, real live donor cards,
/// interactive requisition popup cards, and the "Nearby Donor Network" live OSM map.
class DonorSearchScreen extends ConsumerStatefulWidget {
  const DonorSearchScreen({super.key});

  @override
  ConsumerState<DonorSearchScreen> createState() => _DonorSearchScreenState();
}

class _DonorSearchScreenState extends ConsumerState<DonorSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchPageAsync = ref.watch(donorSearchNotifierProvider);
    final filter = ref.watch(bloodHubFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: CustomAppBar(
        showBackButton: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/blood-hub');
          }
        },
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: RefreshIndicator(
            color: const Color(0xFFC30121),
            onRefresh: () async {
              await ref.read(donorSearchNotifierProvider.notifier).refresh();
              ref.invalidate(donorMapPinsProvider);
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Search Bar (Privacy Locked - Never searches by name or phone)
                DonorSearchBar(
                  searchController: _searchController,
                  onSearchChanged: (val) {
                    ref.read(bloodHubFilterProvider.notifier).update(
                          (s) => s.copyWith(
                            clearQ: val.isEmpty,
                            q: val.isEmpty ? null : val,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 14),

                // 2. Filter Chips: Blood Group, Campus, Division, Zila
                DonorFilterChips(
                  currentFilter: filter,
                  onBloodGroupSelected: (bg) {
                    ref.read(bloodHubFilterProvider.notifier).update(
                          (s) => s.copyWith(
                            clearBloodGroup: bg == null,
                            bloodGroup: bg,
                          ),
                        );
                  },
                  onCampusSelected: (camp) {
                    ref.read(bloodHubFilterProvider.notifier).update(
                          (s) => s.copyWith(
                            clearCampus: camp == null,
                            campus: camp,
                          ),
                        );
                  },
                  onDivisionSelected: (div) {
                    ref.read(bloodHubFilterProvider.notifier).update(
                          (s) => s.copyWith(
                            clearDivision: div == null,
                            division: div,
                            clearDistrict: true,
                          ),
                        );
                  },
                  onDistrictSelected: (dist) {
                    ref.read(bloodHubFilterProvider.notifier).update(
                          (s) => s.copyWith(
                            clearDistrict: dist == null,
                            district: dist,
                          ),
                        );
                  },
                  onResetFilters: () {
                    _searchController.clear();
                    ref.read(bloodHubFilterProvider.notifier).state =
                        const DonorSearchFilter();
                  },
                ),
                const SizedBox(height: 20),

                // 3. Available Donors Header + "Request to All" Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Donors',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        searchPageAsync.maybeWhen(
                          data: (page) => Text(
                            '${page.totalCount} found near you',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF916F6C),
                            ),
                          ),
                          orElse: () => const Text(
                            'Searching donors...',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF916F6C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showRequestAllModal(context, searchPageAsync.valueOrNull?.totalCount ?? 0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF960017),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.campaign_rounded, size: 16),
                      label: const Text(
                        'Request to All',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Donor Cards List
                searchPageAsync.when(
                  data: (page) {
                    if (page.donors.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.person_search_outlined,
                                size: 48,
                                color: Color(0xFF8E7D7F),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No donors found matching criteria',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B2B2B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(bloodHubFilterProvider.notifier).state =
                                      const DonorSearchFilter();
                                },
                                child: const Text(
                                  'Clear All Filters',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFFC30121),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: page.donors.map((donor) {
                        return DonorCard(
                          key: ValueKey('donor_${donor.id}'),
                          donor: donor,
                          onRequestTap: () {
                            context.push(
                              '/blood-hub/request/direct',
                              extra: {
                                'prefill_blood_group': donor.bloodGroup,
                                'prefill_district': donor.district,
                              },
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const DonorSearchSkeleton(),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: Color(0xFFC30121),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Unable to load donors: $error',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF5C3F3D),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(donorSearchNotifierProvider.notifier).refresh();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC30121),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Nearby Donor Network Section Header + Full Screen Map Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nearby Donor Network',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _isMapExpanded = !_isMapExpanded);
                      },
                      icon: Icon(
                        _isMapExpanded
                            ? Icons.close_fullscreen_rounded
                            : Icons.open_in_full_rounded,
                        size: 14,
                        color: const Color(0xFF960017),
                      ),
                      label: Text(
                        _isMapExpanded ? 'Collapse' : 'Full Screen Map',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF960017),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. Interactive OSM Live Donor Map
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isMapExpanded ? 460 : 300,
                  child: const DonorMapView(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Popup card when "Request to All" is tapped
  void _showRequestAllModal(BuildContext context, int count) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                const Text(
                  'Broadcast Request to All Donors',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will dispatch an urgent emergency notification to all $count compatible nearby donors within your active search radius.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF5F5E5E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(
                        '/blood-hub/request/direct',
                        extra: {
                          'mode': 'REQUEST_ALL',
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF960017),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Confirm Emergency Broadcast',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

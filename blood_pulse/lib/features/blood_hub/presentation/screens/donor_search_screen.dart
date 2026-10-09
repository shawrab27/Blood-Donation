// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';
import '../widgets/donor_search/donor_search_bar.dart';
import '../widgets/donor_search/donor_filter_chips.dart';
import '../widgets/donor_search/donor_card.dart';
import '../widgets/donor_search/donor_map_view.dart';
import '../widgets/donor_search/donor_search_skeleton.dart';

/// Screen 2: Donor Search Screen conforming to Stitch UI specification.
class DonorSearchScreen extends ConsumerStatefulWidget {
  const DonorSearchScreen({super.key});

  @override
  ConsumerState<DonorSearchScreen> createState() => _DonorSearchScreenState();
}

class _DonorSearchScreenState extends ConsumerState<DonorSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isMapVisible = false;

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2B2B2B)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/blood-hub');
            }
          },
        ),
        title: const Text(
          'Search Donors',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2B2B),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              context.push(
                '/blood-hub/request/direct',
                extra: {
                  'prefill_blood_group': filter.bloodGroup,
                  'mode': 'REQUEST_ALL',
                },
              );
            },
            icon: const Icon(Icons.group_add_rounded, size: 16, color: Color(0xFFC30121)),
            label: const Text(
              'Request to All',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC30121),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: RefreshIndicator(
            color: const Color(0xFFC30121),
            onRefresh: () async {
              await ref.read(donorSearchNotifierProvider.notifier).refresh();
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Top Search Bar + Toggle
                DonorSearchBar(
                  searchController: _searchController,
                  onSearchChanged: (val) {
                    setState(() {});
                  },
                  onRequestModeTap: () => context.push('/blood-hub/request/direct'),
                ),
                const SizedBox(height: 14),

                // Filter Chips
                DonorFilterChips(
                  currentFilter: filter,
                  isMapVisible: _isMapVisible,
                  onToggleMap: () => setState(() => _isMapVisible = !_isMapVisible),
                  onBloodGroupSelected: (bg) {
                    ref.read(bloodHubFilterProvider.notifier).update(
                          (s) => s.copyWith(
                            clearBloodGroup: bg == null,
                            bloodGroup: bg,
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
                ),
                const SizedBox(height: 16),

                // Map View
                if (_isMapVisible) ...[
                  const DonorMapView(),
                  const SizedBox(height: 16),
                ],

                // Results Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Available Donors',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF24191A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    searchPageAsync.maybeWhen(
                      data: (page) => Text(
                        '${page.totalCount} found near you',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF916F6C),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Donor Results List with Loading / Error / Empty States
                searchPageAsync.when(
                  data: (page) {
                    final query = _searchController.text.trim().toLowerCase();
                    final donors = query.isEmpty
                        ? page.donors
                        : page.donors.where((d) {
                            return d.name.toLowerCase().contains(query) ||
                                (d.campus?.toLowerCase().contains(query) ?? false) ||
                                d.district.toLowerCase().contains(query);
                          }).toList();

                    if (donors.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
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
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(bloodHubFilterProvider.notifier).state =
                                      const DonorSearchFilter();
                                },
                                child: const Text(
                                  'Clear Filters',
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
                      children: donors.map((donor) {
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

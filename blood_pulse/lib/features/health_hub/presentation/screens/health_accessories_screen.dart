import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../domain/models/health_accessory_model.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../widgets/accessories/accessory_card.dart';
import '../widgets/accessories/accessory_detail_sheet.dart';
import '../widgets/accessories/accessory_featured_spotlight.dart';
import '../widgets/accessories/accessory_header_filter.dart';
import '../widgets/common/health_hub_subnav_bar.dart';

class HealthAccessoriesScreen extends ConsumerStatefulWidget {
  const HealthAccessoriesScreen({super.key});

  @override
  ConsumerState<HealthAccessoriesScreen> createState() => _HealthAccessoriesScreenState();
}

class _HealthAccessoriesScreenState extends ConsumerState<HealthAccessoriesScreen> {
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = const [
    'All',
    'Diagnostic & Clinic',
    'Consumables',
    'Parts & Kits',
    'Donor Gear',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchStoreUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open store link: $e', style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openAccessoryDetails(HealthAccessory item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccessoryDetailSheet(
        item: item,
        onOrderNow: _launchStoreUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncAccessories = ref.watch(healthAccessoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: CustomAppBar(
        showBackButton: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/health-hub');
          }
        },
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 840,
          child: asyncAccessories.when(
            loading: () => const Center(child: AppLoader()),
            error: (e, st) => const Center(
              child: Text(
                'Unable to load accessories catalog.',
                style: TextStyle(fontFamily: 'Inter', color: AppColors.error),
              ),
            ),
            data: (items) {
              final filteredItems = items.where((item) {
                final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
                final matchesSearch = _searchQuery.isEmpty ||
                    item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    item.category.toLowerCase().contains(_searchQuery.toLowerCase());
                return matchesCategory && matchesSearch;
              }).toList();

              final featuredItem = items.isNotEmpty ? items.first : null;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top Subnav
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: HealthHubSubnavBar(activeRoute: '/health-hub/accessories'),
                    ),
                  ),

                  // Header Filter
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: AccessoryHeaderFilter(
                        searchController: _searchController,
                        searchQuery: _searchQuery,
                        selectedCategory: _selectedCategory,
                        categories: _categories,
                        onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                        onClearSearch: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                      ),
                    ),
                  ),

                  // 2nd Position: Featured Spotlight Banner
                  if (_searchQuery.isEmpty && _selectedCategory == 'All' && featuredItem != null)
                    SliverToBoxAdapter(
                      child: AccessoryFeaturedSpotlight(
                        item: featuredItem,
                        onOpenDetails: () => _openAccessoryDetails(featuredItem),
                        onOrderNow: _launchStoreUrl,
                      ),
                    ),

                  // Products List
                  if (filteredItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'No accessories found',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B2B2B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try adjusting your search terms or category filter.',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF757575)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredItems[index];
                            return AccessoryCard(
                              item: item,
                              onOpenDetails: () => _openAccessoryDetails(item),
                              onLaunchStore: _launchStoreUrl,
                            );
                          },
                          childCount: filteredItems.length,
                        ),
                      ),
                    ),

                  // Footer Disclaimer
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFD4D8)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Affiliate & Medical Transparency',
                                    style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'These are general product search links, not endorsements from specific sellers. Sponsored — BloodPulse may earn a commission from purchases.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Color(0xFF555555),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

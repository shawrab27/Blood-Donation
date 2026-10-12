// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../domain/models/product_model.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../widgets/accessories/accessory_header_filter.dart';
import '../widgets/accessories/product_card.dart';
import '../widgets/accessories/product_detail_sheet.dart';
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
    'Tier 1 • Diagnostics',
    'Tier 2 • Consumables',
    'Tier 3 • Parts & Cuffs',
    'Tier 4 • Donor Gear',
  ];

  int? get _selectedTierNumber {
    switch (_selectedCategory) {
      case 'Tier 1 • Diagnostics':
        return 1;
      case 'Tier 2 • Consumables':
        return 2;
      case 'Tier 3 • Parts & Cuffs':
        return 3;
      case 'Tier 4 • Donor Gear':
        return 4;
      default:
        return null;
    }
  }

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

  void _openProductDetails(ProductModel item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(
        product: item,
        onOrderNow: _launchStoreUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(
      productsProvider((query: _searchQuery, tier: _selectedTierNumber)),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount;
    if (screenWidth >= 600) {
      crossAxisCount = 3;
    } else if (screenWidth >= 350) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

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
          maxWidth: 960,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Subnav
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: HealthHubSubnavBar(activeRoute: '/health-hub/accessories'),
                ),
              ),

              // Header Filter (Search + Tier Choice Chips)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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

              // Product Grid / State Handling
              asyncProducts.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppLoader()),
                ),
                error: (e, st) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.neutral),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to connect to accessories catalog',
                            style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please check your internet connection or try again.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF666666)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.invalidate(productsProvider),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return SliverFillRemaining(
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
                                'Try adjusting your search terms or tier filter.',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF757575)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final double baseHeight;
                  if (crossAxisCount == 1) {
                    baseHeight = 360.0;
                  } else if (crossAxisCount == 2) {
                    baseHeight = 440.0;
                  } else {
                    baseHeight = 420.0;
                  }
                  final itemHeight = baseHeight * (textScale > 1.0 ? textScale : 1.0);

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 14,
                        mainAxisExtent: itemHeight,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = products[index];
                          return ProductCard(
                            product: item,
                            onOpenDetails: () => _openProductDetails(item),
                            onLaunchStore: _launchStoreUrl,
                          );
                        },
                        childCount: products.length,
                      ),
                    ),
                  );
                },
              ),

              // Footer Transparency Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
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
                                'Price Transparency & External Partners',
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Prices listed are approximate market estimates in Bangladeshi Taka (BDT) and may vary by pharmacy or distributor. BloodPulse does not sell these products directly; tapping links directs you to verified third-party retailers.',
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
          ),
        ),
      ),
    );
  }
}

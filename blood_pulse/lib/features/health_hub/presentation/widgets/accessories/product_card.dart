// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../domain/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onOpenDetails;
  final ValueChanged<String> onLaunchStore;

  const ProductCard({
    super.key,
    required this.product,
    required this.onOpenDetails,
    required this.onLaunchStore,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = product.primaryImageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E5E5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpenDetails,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Tier Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.tierBgColor,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    product.tierName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: product.tierColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Image / Icon Center
                AspectRatio(
                  aspectRatio: 1.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: product.tierBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: product.primaryImageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            placeholder: (_, __) => const Center(child: AppLoader.small()),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(product.iconData, color: product.tierColor, size: 30),
                            ),
                          )
                        : Center(
                            child: Icon(product.iconData, color: product.tierColor, size: 32),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),

                // Description
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF666666),
                    height: 1.25,
                  ),
                ),
                const Spacer(),

                // Estimated Price
                const Text(
                  'ESTIMATED PRICE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Approx. ${product.priceRangeText}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Prices may vary by seller',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    color: Color(0xFF888888),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),

                // Action Button: Visit [store_name] / Visit Website
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onLaunchStore(product.externalUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 12),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        product.storeName.isNotEmpty
                            ? 'Visit ${product.storeName}'
                            : 'Visit Website',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(48, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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

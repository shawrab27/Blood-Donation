// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../domain/models/product_model.dart';

class ProductDetailSheet extends StatelessWidget {
  final ProductModel product;
  final ValueChanged<String> onOrderNow;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.onOrderNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 540,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tier Badge & Close
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.tierBgColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          product.tierName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: product.tierColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F1F8),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: Color(0xFF0D68AA)),
                            SizedBox(width: 4),
                            Text(
                              'Verified Clinical Specs',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0D68AA)),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF666666)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Image or Icon Hero
                  if (product.primaryImageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: product.primaryImageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          placeholder: (_, __) => const Center(child: AppLoader()),
                          errorWidget: (_, __, ___) => Container(
                            color: product.tierBgColor,
                            child: Icon(product.iconData, color: product.tierColor, size: 48),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: product.tierBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(product.iconData, color: product.tierColor, size: 48),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Product Title
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  const Text(
                    'Product Overview & Clinical Use',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF555555), height: 1.45),
                  ),

                  const SizedBox(height: 16),

                  // Specifications Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3DDE0)),
                    ),
                    child: Column(
                      children: [
                        if (product.availabilityText.isNotEmpty) ...[
                          _buildSpecRow(Icons.local_shipping_outlined, 'Availability', product.availabilityText),
                          const SizedBox(height: 10),
                        ],
                        _buildSpecRow(Icons.storefront_outlined, 'Vendor / Partner', product.storeName.isNotEmpty ? product.storeName : 'Third-party retailer'),
                        const SizedBox(height: 10),
                        _buildSpecRow(Icons.health_and_safety_outlined, 'Standard', 'Medical Grade • Calibrated'),
                        const SizedBox(height: 10),
                        _buildSpecRow(Icons.info_outline, 'Pricing Note', 'Approximate market range. Prices may vary.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Price & Visit Button
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESTIMATED PRICE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Approx. ${product.priceRangeText}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'Prices may vary by vendor',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Color(0xFF888888),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onOrderNow(product.externalUrl);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
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
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFC30121)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

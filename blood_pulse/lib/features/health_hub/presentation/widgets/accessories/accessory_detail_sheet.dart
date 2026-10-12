// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/health_accessory_model.dart';

class AccessoryDetailSheet extends StatelessWidget {
  final HealthAccessory item;
  final ValueChanged<String> onOrderNow;

  const AccessoryDetailSheet({
    super.key,
    required this.item,
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
                  // Category Tier Badge + Reviews Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.bgLightColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          item.tier,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item.accentColor,
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
                              'Quality Standards',
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
                  const SizedBox(height: 12),

                  // Large Icon & Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: item.bgLightColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(item.icon, color: item.accentColor, size: 32),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B2B2B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF2E6E6)),
                  const SizedBox(height: 12),

                  // Detailed Description
                  const Text(
                    'Product Overview & Clinical Use',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF555555), height: 1.5),
                  ),

                  const SizedBox(height: 16),

                  // Key Specifications Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3DDE0)),
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow(Icons.local_shipping_outlined, 'Availability', 'In Stock • 24-48h Delivery'),
                        const SizedBox(height: 10),
                        _buildSpecRow(Icons.storefront_outlined, 'Vendor / Partner', item.storeName),
                        const SizedBox(height: 10),
                        _buildSpecRow(Icons.health_and_safety_outlined, 'Safety Standard', 'Medical Grade • Calibrated'),
                        const SizedBox(height: 10),
                        _buildSpecRow(Icons.replay_circle_filled_rounded, 'Warranty & Return', '7-Day Return • 1-Year Guarantee'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Price & Actions
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
                            'PRICE ESTIMATE',
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
                            'Approx. ${item.priceRange}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC30121),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onOrderNow(item.affiliateUrl);
                        },
                        icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Order on ${item.storeName}'),
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

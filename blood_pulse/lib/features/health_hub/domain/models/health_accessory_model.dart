// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

class HealthAccessory {
  final String id;
  final String title;
  final String category;
  final String description;
  final String priceRange;
  final String affiliateUrl;
  final String storeName;
  final bool isActive;
  final int displayOrder;

  const HealthAccessory({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.priceRange,
    required this.affiliateUrl,
    required this.storeName,
    required this.isActive,
    required this.displayOrder,
  });

  factory HealthAccessory.fromJson(Map<String, dynamic> json) {
    return HealthAccessory(
      id: json['id']?.toString() ?? '',
      title: json['name_en'] ?? '',
      category: json['category'] ?? '',
      description: json['description_en'] ?? '',
      priceRange: json['price_range_text'] ?? '',
      affiliateUrl: json['affiliate_url'] ?? '',
      storeName: json['store_name'] ?? '',
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
    );
  }

  String get tier => 'Health Item';
  double get rating => 4.8;
  int get reviewsCount => 150;
  
  IconData get icon {
    switch (category) {
      case 'Diagnostic & Clinic': return Icons.monitor_heart_outlined;
      case 'Consumables': return Icons.biotech_outlined;
      case 'Parts & Kits': return Icons.build_circle_outlined;
      case 'Donor Gear': return Icons.stars_outlined;
      default: return Icons.medical_services_outlined;
    }
  }

  Color get accentColor {
    switch (category) {
      case 'Diagnostic & Clinic': return const Color(0xFF0D68AA);
      case 'Consumables': return const Color(0xFFE65100);
      case 'Parts & Kits': return const Color(0xFF6A1B9A);
      case 'Donor Gear': return const Color(0xFFC30121);
      default: return const Color(0xFF1B8A4E);
    }
  }

  Color get bgLightColor {
    switch (category) {
      case 'Diagnostic & Clinic': return const Color(0xFFEDF4FF);
      case 'Consumables': return const Color(0xFFFFF3E0);
      case 'Parts & Kits': return const Color(0xFFF3E5F5);
      case 'Donor Gear': return const Color(0xFFFFF0F1);
      default: return const Color(0xFFE8F5E9);
    }
  }
}

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

  static const List<HealthAccessory> curatedAccessories = [
    HealthAccessory(
      id: 'acc-1',
      title: 'Digital Blood Pressure & Pulse Monitor',
      category: 'Diagnostic & Clinic',
      description: 'Accurate upper-arm digital sphygmomanometer with arrhythmia detection for donor pre-screening vitals.',
      priceRange: '৳ 2,200 - ৳ 3,500',
      affiliateUrl: 'https://www.daraz.com.bd/catalog/?q=blood+pressure+monitor',
      storeName: 'Daraz BD Medical',
      isActive: true,
      displayOrder: 1,
    ),
    HealthAccessory(
      id: 'acc-2',
      title: 'Fingertip Pulse Oximeter with SpO2 Sensor',
      category: 'Diagnostic & Clinic',
      description: 'Real-time blood oxygen saturation (SpO2) and pulse rate monitor with OLED display.',
      priceRange: '৳ 750 - ৳ 1,400',
      affiliateUrl: 'https://www.daraz.com.bd/catalog/?q=pulse+oximeter',
      storeName: 'Medistore BD',
      isActive: true,
      displayOrder: 2,
    ),
    HealthAccessory(
      id: 'acc-3',
      title: 'ABO & Rh Blood Typing Rapid Test Kit',
      category: 'Parts & Kits',
      description: 'Fast 2-minute bedside agglutination test card kit for educational and laboratory blood group typing.',
      priceRange: '৳ 450 - ৳ 850',
      affiliateUrl: 'https://www.daraz.com.bd/catalog/?q=blood+group+test+kit',
      storeName: 'BioLab Supply',
      isActive: true,
      displayOrder: 3,
    ),
    HealthAccessory(
      id: 'acc-4',
      title: 'Iron & Folic Acid Restoration Capsules (60s)',
      category: 'Consumables',
      description: 'Clinical elemental iron + folic acid supplements for rapid post-donation hemoglobin restoration.',
      priceRange: '৳ 280 - ৳ 500',
      affiliateUrl: 'https://arogga.com/brand/folic-acid',
      storeName: 'Arogga Pharmacy',
      isActive: true,
      displayOrder: 4,
    ),
    HealthAccessory(
      id: 'acc-5',
      title: 'Sterile Safety Lancets & Alcohol Prep Pads (100x)',
      category: 'Consumables',
      description: 'Single-use twist-off safety lancets with 70% isopropyl alcohol swabs for sterile capillary sampling.',
      priceRange: '৳ 320 - ৳ 600',
      affiliateUrl: 'https://www.daraz.com.bd/catalog/?q=blood+lancets',
      storeName: 'Clinical Essentials',
      isActive: true,
      displayOrder: 5,
    ),
    HealthAccessory(
      id: 'acc-6',
      title: 'Donor Ergonomic Hand Grip Stress Ball',
      category: 'Donor Gear',
      description: 'Medical-grade squeeze therapy ball designed to promote smooth venous blood flow during venipuncture.',
      priceRange: '৳ 150 - ৳ 350',
      affiliateUrl: 'https://www.daraz.com.bd/catalog/?q=squeeze+stress+ball',
      storeName: 'Pulse Gear',
      isActive: true,
      displayOrder: 6,
    ),
    HealthAccessory(
      id: 'acc-7',
      title: 'Electrolyte Hydration Flask & Oral Rehydration Salts',
      category: 'Donor Gear',
      description: 'BPA-free vacuum insulated stainless steel water bottle with 10 sachets of WHO-formula ORS for recovery.',
      priceRange: '৳ 650 - ৳ 1,100',
      affiliateUrl: 'https://arogga.com/product/ors',
      storeName: 'HealthLife BD',
      isActive: true,
      displayOrder: 7,
    ),
  ];
}


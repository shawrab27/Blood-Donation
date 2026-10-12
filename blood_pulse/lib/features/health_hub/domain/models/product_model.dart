// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

class ProductImageModel {
  final int id;
  final String url;
  final String publicId;
  final int sortOrder;

  const ProductImageModel({
    required this.id,
    required this.url,
    this.publicId = '',
    this.sortOrder = 0,
  });

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      url: json['url'] ?? '',
      publicId: json['public_id'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'public_id': publicId,
    'sort_order': sortOrder,
  };
}

class ProductModel {
  final int id;
  final String name;
  final int tier; // 1 to 4
  final String description;
  final double priceMin;
  final double priceMax;
  final String currency;
  final String externalUrl;
  final String storeName;
  final bool isActive;
  final bool isFeatured;
  final int sortOrder;
  final String availabilityText;
  final String priceRangeText;
  final List<ProductImageModel> images;

  const ProductModel({
    required this.id,
    required this.name,
    required this.tier,
    required this.description,
    required this.priceMin,
    required this.priceMax,
    this.currency = 'BDT',
    required this.externalUrl,
    required this.storeName,
    this.isActive = true,
    this.isFeatured = false,
    this.sortOrder = 0,
    this.availabilityText = '',
    this.priceRangeText = '',
    this.images = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    var imgs = <ProductImageModel>[];
    if (json['images'] is List) {
      imgs = (json['images'] as List)
          .map((item) => ProductImageModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      tier: json['tier'] is int ? json['tier'] : int.tryParse(json['tier']?.toString() ?? '1') ?? 1,
      description: json['description'] ?? '',
      priceMin: (json['price_min'] as num?)?.toDouble() ?? 0.0,
      priceMax: (json['price_max'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'BDT',
      externalUrl: json['external_url'] ?? '',
      storeName: json['store_name'] ?? '',
      isActive: json['is_active'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      sortOrder: json['sort_order'] ?? 0,
      availabilityText: json['availability_text'] ?? '',
      priceRangeText: json['price_range_text'] ?? '',
      images: imgs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tier': tier,
    'description': description,
    'price_min': priceMin,
    'price_max': priceMax,
    'currency': currency,
    'external_url': externalUrl,
    'store_name': storeName,
    'is_active': isActive,
    'is_featured': isFeatured,
    'sort_order': sortOrder,
    'availability_text': availabilityText,
    'price_range_text': priceRangeText,
    'images': images.map((i) => i.toJson()).toList(),
  };

  String get tierName {
    switch (tier) {
      case 1:
        return 'Tier 1 • Diagnostics';
      case 2:
        return 'Tier 2 • Consumables';
      case 3:
        return 'Tier 3 • Parts & Cuffs';
      case 4:
        return 'Tier 4 • Donor Gear';
      default:
        return 'Tier $tier';
    }
  }

  Color get tierColor {
    switch (tier) {
      case 1:
        return const Color(0xFF0D68AA);
      case 2:
        return const Color(0xFFE65100);
      case 3:
        return const Color(0xFF6A1B9A);
      case 4:
        return const Color(0xFFC30121);
      default:
        return const Color(0xFF2B2B2B);
    }
  }

  Color get tierBgColor {
    switch (tier) {
      case 1:
        return const Color(0xFFEDF4FF);
      case 2:
        return const Color(0xFFFFF3E0);
      case 3:
        return const Color(0xFFF3E5F5);
      case 4:
        return const Color(0xFFFFF0F1);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  IconData get iconData {
    switch (tier) {
      case 1:
        return Icons.monitor_heart_outlined;
      case 2:
        return Icons.biotech_outlined;
      case 3:
        return Icons.build_circle_outlined;
      case 4:
        return Icons.stars_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  String get primaryImageUrl => images.isNotEmpty ? images.first.url : '';
}

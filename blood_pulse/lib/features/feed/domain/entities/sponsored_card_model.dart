// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

/// Domain entity representing a sponsored campaign or announcement card in the social feed.
class SponsoredCardModel {
  final int id;
  final String title;
  final String shortText;
  final String body;
  final String? image;
  final String sponsorName;
  final String kind;
  final String ctaType; // 'link', 'call', 'none'
  final String ctaValue;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final int priority;

  const SponsoredCardModel({
    required this.id,
    required this.title,
    required this.shortText,
    required this.body,
    this.image,
    required this.sponsorName,
    required this.kind,
    required this.ctaType,
    required this.ctaValue,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.priority = 0,
  });

  factory SponsoredCardModel.fromJson(Map<String, dynamic> json) {
    return SponsoredCardModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      shortText: json['short_text']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      image: json['image']?.toString(),
      sponsorName: json['sponsor_name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'sponsored',
      ctaType: json['cta_type']?.toString().toLowerCase() ?? 'none',
      ctaValue: json['cta_value']?.toString() ?? '',
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
      priority: json['priority'] is int
          ? json['priority'] as int
          : int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
    );
  }
}

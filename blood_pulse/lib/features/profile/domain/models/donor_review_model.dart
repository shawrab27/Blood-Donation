// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

class DonorReviewItem {
  final int id;
  final String reviewerName;
  final int stars;
  final String tag;
  final String comment;
  final String createdAt;

  DonorReviewItem({
    required this.id,
    required this.reviewerName,
    required this.stars,
    this.tag = '',
    this.comment = '',
    required this.createdAt,
  });

  factory DonorReviewItem.fromJson(Map<String, dynamic> json) {
    return DonorReviewItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reviewerName: (json['reviewer_name'] ?? 'Blood Recipient').toString(),
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      tag: (json['tag'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  String get timeAgo {
    try {
      final dt = DateTime.tryParse(createdAt);
      if (dt == null) return createdAt;
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return createdAt;
    }
  }
}

class DonorReviewsResponse {
  final double ratingAvg;
  final int ratingCount;
  final List<DonorReviewItem> reviews;

  DonorReviewsResponse({
    required this.ratingAvg,
    required this.ratingCount,
    required this.reviews,
  });

  factory DonorReviewsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['results'] as List<dynamic>? ?? [])
        .map((e) => DonorReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return DonorReviewsResponse(
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      reviews: list,
    );
  }
}

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.timestamp,
    this.authorAvatar,
  });

  final String id;
  final String authorName;
  final String text;
  final String timestamp;
  final String? authorAvatar;
}

enum AuthorRole { official, verifiedClinic, goldDonor, donor, system }

class FeedPostItem {
  const FeedPostItem({
    required this.id,
    required this.authorName,
    this.authorAvatar,
    this.authorRole = AuthorRole.donor,
    this.roleBadgeText,
    required this.timestamp,
    required this.content,
    this.urgentNeedBadge,
    this.bloodGroupBadge,
    this.achievementBadge,
    this.imageUrl,
    this.imageBytes,
    this.location,
    this.reactCount = 0,
    this.isReacted = false,
    this.commentCount = 0,
    this.comments = const [],
    this.repostCount = 0,
    this.isReposted = false,
    this.shareCount = 0,
  });

  final String id;
  final String authorName;
  final String? authorAvatar;
  final AuthorRole authorRole;
  final String? roleBadgeText; // e.g. "Official", "Verified Clinic", "Gold Donor"
  final String timestamp;
  final String content;
  final String? urgentNeedBadge; // e.g. "URGENT NEED"
  final String? bloodGroupBadge; // e.g. "O- Negative"
  final String? achievementBadge; // e.g. "Platinum Badge"
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? location;
  final int reactCount;
  final bool isReacted;
  final int commentCount;
  final List<FeedComment> comments;
  final int repostCount;
  final bool isReposted;
  final int shareCount;

  FeedPostItem copyWith({
    int? reactCount,
    bool? isReacted,
    int? commentCount,
    List<FeedComment>? comments,
    int? repostCount,
    bool? isReposted,
    int? shareCount,
  }) {
    return FeedPostItem(
      id: id,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorRole: authorRole,
      roleBadgeText: roleBadgeText,
      timestamp: timestamp,
      content: content,
      urgentNeedBadge: urgentNeedBadge,
      bloodGroupBadge: bloodGroupBadge,
      achievementBadge: achievementBadge,
      imageUrl: imageUrl,
      imageBytes: imageBytes,
      location: location,
      reactCount: reactCount ?? this.reactCount,
      isReacted: isReacted ?? this.isReacted,
      commentCount: commentCount ?? this.commentCount,
      comments: comments ?? this.comments,
      repostCount: repostCount ?? this.repostCount,
      isReposted: isReposted ?? this.isReposted,
      shareCount: shareCount ?? this.shareCount,
    );
  }
}

class AdminAdBanner {
  const AdminAdBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    this.ctaText = 'Support the Cause',
    this.ctaLink,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageAsset;
  final String ctaText;
  final String? ctaLink;
}

class UrgentNeedItem {
  const UrgentNeedItem({
    required this.id,
    required this.hospitalName,
    required this.urgencyText,
    required this.unitsNeeded,
    required this.distance,
    required this.bloodGroup,
    required this.contactPhone,
  });

  final String id;
  final String hospitalName;
  final String urgencyText;
  final int unitsNeeded;
  final String distance;
  final String bloodGroup;
  final String contactPhone;
}

class TopDonorItem {
  const TopDonorItem({
    required this.id,
    required this.name,
    required this.donationsCount,
    required this.avatarInitials,
    this.bloodGroup = 'O+',
  });

  final String id;
  final String name;
  final int donationsCount;
  final String avatarInitials;
  final String bloodGroup;
}

class FeedNotifier extends StateNotifier<List<FeedPostItem>> {
  FeedNotifier() : super(_initialPosts);

  static final List<FeedPostItem> _initialPosts = [
    // Post 1: City Central Blood Bank / City General Hospital Urgent Call
    const FeedPostItem(
      id: 'post_1',
      authorName: 'City Central Blood Bank',
      authorRole: AuthorRole.verifiedClinic,
      roleBadgeText: 'Verified Clinic',
      timestamp: '2 hours ago',
      urgentNeedBadge: 'URGENT NEED',
      bloodGroupBadge: 'O- Negative',
      location: 'Central Trauma Wing, Block B',
      content: 'We are currently experiencing a critical shortage of O Negative blood. Your donation today could save up to three lives in our pediatric ward. Walk-ins are accepted and prioritized.',
      imageUrl: 'assets/images/clinic_feed_photo.jpg',
      reactCount: 1200,
      commentCount: 84,
      repostCount: 142,
      comments: [
        FeedComment(
          id: 'c1',
          authorName: 'Dr. Rafiqul Islam',
          text: 'Pediatric ICU urgently awaits matching O- donors today. Please share widely.',
          timestamp: '1 hour ago',
        ),
      ],
    ),

    // Post 2: Sarah Mitchell Milestone 5th Donation Story
    const FeedPostItem(
      id: 'post_2',
      authorName: 'Sarah Mitchell',
      authorRole: AuthorRole.donor,
      roleBadgeText: 'Milestone: 5th Donation',
      timestamp: 'Donated 15 mins ago',
      achievementBadge: 'Platinum Badge: New Achievement Unlocked',
      location: 'Westside Blood Center',
      content: '“So happy to reach my 5th donation milestone today! The team at Westside Clinic made it so easy and painless. Who’s joining me next week?” #DonateLife #BloodPulseHeroes',
      imageUrl: 'assets/images/splash_hero.jpg',
      reactCount: 348,
      commentCount: 29,
      repostCount: 18,
      comments: [
        FeedComment(
          id: 'c2',
          authorName: 'David Chen',
          text: 'Congratulations Sarah! Welcome to the 5-club! 🎉👏',
          timestamp: '10 mins ago',
        ),
      ],
    ),

    // Post 3: David Chen Gold Donor Story
    const FeedPostItem(
      id: 'post_3',
      authorName: 'David Chen',
      authorRole: AuthorRole.goldDonor,
      roleBadgeText: 'Gold Donor',
      timestamp: '5 hours ago',
      location: 'Westside Blood Center',
      content: 'Just completed my 20th donation today! 🩸 Taking 45 minutes out of your day can literally save three lives. The staff at Westside were incredible as always. If you’ve been on the fence about donating, take this as your sign to book an appointment! #BloodPulse #DonateLife',
      imageUrl: 'assets/images/campaign_banner.jpg',
      reactCount: 158,
      commentCount: 24,
      repostCount: 12,
      comments: [],
    ),

    // Post 4: BloodPulse Health Info Tip
    const FeedPostItem(
      id: 'post_4',
      authorName: 'BloodPulse Health Info',
      authorRole: AuthorRole.system,
      roleBadgeText: 'System Verified',
      timestamp: 'Yesterday',
      content: 'Did you know? Eating iron-rich foods before your donation helps maintain your hemoglobin levels! Good choices include spinach, red meat, beans, and fortified cereals. Remember to hydrate well today if you have an appointment tomorrow. 💧',
      reactCount: 95,
      commentCount: 6,
      repostCount: 21,
    ),
  ];

  void addPost({
    required String authorName,
    required String content,
    Uint8List? imageBytes,
    String? imageUrl,
    String? location,
    String? urgentNeedBadge,
    String? bloodGroupBadge,
  }) {
    final newPost = FeedPostItem(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      authorRole: AuthorRole.donor,
      roleBadgeText: 'Donor Story',
      timestamp: 'Just now',
      content: content,
      imageBytes: imageBytes,
      imageUrl: imageUrl,
      location: location,
      urgentNeedBadge: urgentNeedBadge,
      bloodGroupBadge: bloodGroupBadge,
      reactCount: 0,
      commentCount: 0,
      repostCount: 0,
    );

    state = [newPost, ...state];
  }

  void toggleReact(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            isReacted: !post.isReacted,
            reactCount: post.isReacted ? post.reactCount - 1 : post.reactCount + 1,
          )
        else
          post,
    ];
  }

  void toggleRepost(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            isReposted: !post.isReposted,
            repostCount: post.isReposted ? post.repostCount - 1 : post.repostCount + 1,
          )
        else
          post,
    ];
  }

  void addComment(String postId, String authorName, String text) {
    if (text.trim().isEmpty) return;

    final newComment = FeedComment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      text: text.trim(),
      timestamp: 'Just now',
    );

    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            commentCount: post.commentCount + 1,
            comments: [...post.comments, newComment],
          )
        else
          post,
    ];
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, List<FeedPostItem>>((ref) {
  return FeedNotifier();
});

// Admin-managed Ad / Campaign Banners provider
final adminAdBannerProvider = Provider<AdminAdBanner>((ref) {
  return const AdminAdBanner(
    id: 'ad_1',
    title: 'Support the Cause',
    subtitle: 'Help us reach more donors. Share the BloodPulse app with your network.',
    imageAsset: 'assets/images/campaign_banner.jpg',
    ctaText: 'Share Campaign',
  );
});

// Live Urgent Needs Provider
final liveUrgentNeedsProvider = Provider<List<UrgentNeedItem>>((ref) {
  return const [
    UrgentNeedItem(
      id: 'urgent_1',
      hospitalName: "St. Jude's General Hospital",
      urgencyText: 'Emergency surgery in progress. 4 units needed.',
      unitsNeeded: 4,
      distance: '2km away',
      bloodGroup: 'O-',
      contactPhone: '+8801700000000',
    ),
    UrgentNeedItem(
      id: 'urgent_2',
      hospitalName: 'Dhaka Medical College Hospital',
      urgencyText: 'Thalassemia patient regular transfusion requirement.',
      unitsNeeded: 2,
      distance: '5km away',
      bloodGroup: 'B+',
      contactPhone: '+8801711000000',
    ),
  ];
});

// Top Donors Leaderboard Provider
final topDonorsProvider = Provider<List<TopDonorItem>>((ref) {
  return const [
    TopDonorItem(id: 'd1', name: 'David Chen', donationsCount: 42, avatarInitials: 'DC', bloodGroup: 'O+'),
    TopDonorItem(id: 'd2', name: 'Elena Rodriguez', donationsCount: 38, avatarInitials: 'ER', bloodGroup: 'A+'),
    TopDonorItem(id: 'd3', name: 'Marcus Thorne', donationsCount: 35, avatarInitials: 'MT', bloodGroup: 'B+'),
  ];
});

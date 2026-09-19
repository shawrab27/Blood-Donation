import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_client.dart';

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
    this.repostedBy,
    this.originalAuthor,
    this.originalContent,
    this.originalLocation,
    this.originalImageUrl,
    this.originalImageBytes,
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
  final String? repostedBy;
  final String? originalAuthor;
  final String? originalContent;
  final String? originalLocation;
  final String? originalImageUrl;
  final Uint8List? originalImageBytes;

  FeedPostItem copyWith({
    String? id,
    int? reactCount,
    bool? isReacted,
    int? commentCount,
    List<FeedComment>? comments,
    int? repostCount,
    bool? isReposted,
    int? shareCount,
    String? repostedBy,
    String? originalAuthor,
    String? originalContent,
    String? originalLocation,
    String? originalImageUrl,
    Uint8List? originalImageBytes,
  }) {
    return FeedPostItem(
      id: id ?? this.id,
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
      repostedBy: repostedBy ?? this.repostedBy,
      originalAuthor: originalAuthor ?? this.originalAuthor,
      originalContent: originalContent ?? this.originalContent,
      originalLocation: originalLocation ?? this.originalLocation,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      originalImageBytes: originalImageBytes ?? this.originalImageBytes,
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

  final ApiClient _apiClient = ApiClient();

  Future<void> fetchPosts() async {
    try {
      final response = await _apiClient.get('posts/');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final fetched = list.map((item) {
            final commentsList = (item['comments'] as List<dynamic>?)?.map((c) => FeedComment(
              id: c['id'].toString(),
              authorName: c['author']?.toString() ?? 'Community Member',
              text: c['text']?.toString() ?? '',
              timestamp: 'Recent',
            )).toList() ?? <FeedComment>[];

            final String? repostedBy = item['reposted_by']?.toString();
            final String? originalAuthor = item['original_author_name']?.toString();
            return FeedPostItem(
              id: item['id'].toString(),
              authorName: item['author_name']?.toString() ?? 'Blood Donor',
              authorRole: AuthorRole.donor,
              roleBadgeText: item['original_post'] != null ? 'Reposted Story' : 'Donor Story',
              timestamp: 'Recent',
              content: item['text_content']?.toString() ?? '',
              reactCount: item['likes_count'] as int? ?? (item['reactions_count'] as int? ?? 0),
              commentCount: item['comments_count'] as int? ?? commentsList.length,
              comments: commentsList,
              repostCount: 0,
              repostedBy: repostedBy,
              originalAuthor: originalAuthor,
              originalContent: repostedBy != null ? (item['text_content']?.toString() ?? '') : null,
            );
          }).toList();
          state = [...fetched, ..._initialPosts];
        }
      }
    } catch (e) {
      debugPrint('[FeedNotifier] Error fetching posts: $e');
    }
  }

  Future<bool> addPost({
    required String authorName,
    required String content,
    Uint8List? imageBytes,
    String? imageUrl,
    String? location,
    String? urgentNeedBadge,
    String? bloodGroupBadge,
    void Function(String error)? onError,
  }) async {
    try {
      final response = await _apiClient.post('posts/', body: {
        'text_content': content,
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final newPost = FeedPostItem(
          id: data['id']?.toString() ?? 'post_${DateTime.now().millisecondsSinceEpoch}',
          authorName: data['author_name']?.toString() ?? authorName,
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
        return true;
      } else {
        final err = 'Failed to post [${response.statusCode}]: ${response.body}';
        onError?.call(err);
        return false;
      }
    } catch (e) {
      final err = 'Error creating post: $e';
      onError?.call(err);
      return false;
    }
  }

  Future<bool> toggleReact(String postId, {void Function(String error)? onError}) async {
    final postIndex = state.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return false;
    final currentPost = state[postIndex];

    // 1. Instant optimistic update for immediate user feedback
    final bool newIsReacted = !currentPost.isReacted;
    final int newCount = newIsReacted
        ? currentPost.reactCount + 1
        : (currentPost.reactCount > 0 ? currentPost.reactCount - 1 : 0);

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == postIndex)
          state[i].copyWith(
            reactCount: newCount,
            isReacted: newIsReacted,
          )
        else
          state[i],
    ];

    // 2. Synchronize with backend if this is an active numeric database ID
    if (int.tryParse(postId) != null) {
      try {
        final response = await _apiClient.post('posts/$postId/react/');
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final int serverCount = data['react_count'] as int? ?? newCount;
          final bool serverIsReacted = data['is_reacted'] as bool? ?? newIsReacted;
          state = [
            for (final post in state)
              if (post.id == postId)
                post.copyWith(
                  reactCount: serverCount,
                  isReacted: serverIsReacted,
                )
              else
                post,
          ];
        }
      } catch (e) {
        debugPrint('[FeedProvider] Background react sync warning: $e');
        // Do not display 404 error banner for non-critical reaction sync
      }
    }

    return true;
  }

  Future<bool> toggleRepost(String postId, {String? reposterName, void Function(String error)? onError}) async {
    return repost(postId, reposterName: reposterName, onError: onError);
  }

  Future<bool> repost(String postId, {String? reposterName, void Function(String error)? onError}) async {
    final originalIndex = state.indexWhere((p) => p.id == postId);
    final original = originalIndex != -1 ? state[originalIndex] : null;
    final fallbackReposter = reposterName ?? 'You';
    final effectiveReposter = fallbackReposter.isNotEmpty ? fallbackReposter : 'You';
    final repostId = 'repost_${DateTime.now().millisecondsSinceEpoch}';

    // Optimistically create the repost item immediately for real-time responsiveness
    final newPost = FeedPostItem(
      id: repostId,
      authorName: original?.authorName ?? 'Community Member',
      authorAvatar: original?.authorAvatar,
      authorRole: original?.authorRole ?? AuthorRole.donor,
      roleBadgeText: original?.roleBadgeText ?? 'Donor Story',
      timestamp: 'Just now',
      content: original?.content ?? '',
      location: original?.location,
      imageUrl: original?.imageUrl,
      imageBytes: original?.imageBytes,
      urgentNeedBadge: original?.urgentNeedBadge,
      bloodGroupBadge: original?.bloodGroupBadge,
      achievementBadge: original?.achievementBadge,
      repostedBy: effectiveReposter,
      originalAuthor: original?.authorName,
      originalContent: original?.content,
      originalLocation: original?.location,
      originalImageUrl: original?.imageUrl,
      originalImageBytes: original?.imageBytes,
      reactCount: 0,
      commentCount: 0,
      repostCount: 0,
    );

    state = [
      newPost,
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            repostCount: post.repostCount + 1,
            isReposted: true,
          )
        else
          post,
    ];

    // Attempt backend sync in background without blocking local success
    try {
      if (int.tryParse(postId) != null) {
        final response = await _apiClient.post('posts/$postId/repost/');
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          if (data['id'] != null) {
            state = [
              for (final p in state)
                if (p.id == repostId) p.copyWith(id: data['id'].toString()) else p,
            ];
          }
        }
      } else {
        // Fallback sync for mock/demo posts
        try {
          await _apiClient.post('posts/', body: {
            'text_content': '🔁 Repost: ${original?.content ?? ''}',
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[FeedNotifier] Backend repost sync notice: $e');
    }

    return true;
  }

  Future<bool> addComment(String postId, String text, {void Function(String error)? onError}) async {
    if (text.trim().isEmpty) return false;
    try {
      final response = await _apiClient.post(
        'posts/$postId/comments/',
        body: {'text': text.trim()},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final newComment = FeedComment(
          id: data['id']?.toString() ?? 'comment_${DateTime.now().millisecondsSinceEpoch}',
          authorName: data['author']?.toString() ?? 'Community Member',
          text: data['text']?.toString() ?? text.trim(),
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
        return true;
      } else {
        final err = 'Failed to add comment [${response.statusCode}]: ${response.body}';
        onError?.call(err);
        return false;
      }
    } catch (e) {
      final err = 'Error adding comment: $e';
      onError?.call(err);
      return false;
    }
  }

  void incrementShare(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            shareCount: post.shareCount + 1,
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

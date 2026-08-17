import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String authorName;
  final String text;
  final String timestamp;
}

class FeedPostItem {
  const FeedPostItem({
    required this.id,
    required this.authorName,
    this.authorBloodGroup,
    required this.timestamp,
    required this.content,
    this.imageUrl,
    this.feeling,
    this.location,
    this.reactCount = 0,
    this.isReacted = false,
    this.commentCount = 0,
    this.comments = const [],
    this.repostCount = 0,
    this.isReposted = false,
    this.urgencyBadge,
  });

  final String id;
  final String authorName;
  final String? authorBloodGroup;
  final String timestamp;
  final String content;
  final String? imageUrl;
  final String? feeling;
  final String? location;
  final int reactCount;
  final bool isReacted;
  final int commentCount;
  final List<FeedComment> comments;
  final int repostCount;
  final bool isReposted;
  final String? urgencyBadge; // e.g. 'Critical', 'Urgent'

  FeedPostItem copyWith({
    int? reactCount,
    bool? isReacted,
    int? commentCount,
    List<FeedComment>? comments,
    int? repostCount,
    bool? isReposted,
  }) {
    return FeedPostItem(
      id:               id,
      authorName:       authorName,
      authorBloodGroup: authorBloodGroup,
      timestamp:        timestamp,
      content:          content,
      imageUrl:         imageUrl,
      feeling:          feeling,
      location:         location,
      reactCount:       reactCount ?? this.reactCount,
      isReacted:        isReacted  ?? this.isReacted,
      commentCount:     commentCount ?? this.commentCount,
      comments:         comments   ?? this.comments,
      repostCount:      repostCount ?? this.repostCount,
      isReposted:       isReposted ?? this.isReposted,
      urgencyBadge:     urgencyBadge,
    );
  }
}

class FeedNotifier extends StateNotifier<List<FeedPostItem>> {
  FeedNotifier() : super(_initialPosts);

  static final List<FeedPostItem> _initialPosts = [
    FeedPostItem(
      id: 'p1',
      authorName: 'Badhan DU Central',
      authorBloodGroup: 'O+',
      timestamp: '10 mins ago',
      content: '🚨 URGENT EMERGENCY: 2 Bags of O+ Blood needed immediately for a surgery patient at Dhaka Medical College Hospital, Ward 4.',
      urgencyBadge: 'Critical',
      reactCount: 24,
      commentCount: 5,
      comments: const [
        FeedComment(id: 'c1', authorName: 'Rahim Ahmed', text: 'I am O+ and nearby. Contacting now!', timestamp: '8 mins ago'),
        FeedComment(id: 'c2', authorName: 'Sandhani Team', text: 'Shared in our DU messaging loop.', timestamp: '5 mins ago'),
      ],
      repostCount: 12,
    ),
    FeedPostItem(
      id: 'p2',
      authorName: 'Tanvir Hossain',
      authorBloodGroup: 'AB+',
      timestamp: '1 hour ago',
      feeling: 'Feeling Thankful 😊',
      location: 'Square Hospital, Dhaka',
      content: 'Successfully donated 1 bag of AB+ blood today! Big thanks to the BloodPulse team for rapid donor matching. #GiveLife #BloodPulse',
      reactCount: 58,
      commentCount: 8,
      comments: const [
        FeedComment(id: 'c3', authorName: 'Nusrat Jahan', text: 'Proud of you brother! Real hero 👏', timestamp: '40 mins ago'),
      ],
      repostCount: 7,
    ),
    FeedPostItem(
      id: 'p3',
      authorName: 'Sandhani DMC Unit',
      authorBloodGroup: 'B-',
      timestamp: '3 hours ago',
      content: 'Notice: Voluntary Blood Donation & Health Screening Camp happening tomorrow at Curzon Hall, DU. Everyone is welcome!',
      urgencyBadge: 'Event',
      reactCount: 102,
      commentCount: 14,
      comments: const [],
      repostCount: 35,
    ),
  ];

  void addPost({
    required String authorName,
    required String content,
    String? imageUrl,
    String? feeling,
    String? location,
  }) {
    final newPost = FeedPostItem(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName,
      timestamp: 'Just now',
      content: content,
      imageUrl: imageUrl,
      feeling: feeling,
      location: location,
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
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
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

final feedProvider =
    StateNotifierProvider<FeedNotifier, List<FeedPostItem>>((ref) => FeedNotifier());

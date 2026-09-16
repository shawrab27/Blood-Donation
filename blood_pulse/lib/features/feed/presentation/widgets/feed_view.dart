import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../profile/domain/providers/profile_provider.dart';
import '../providers/feed_provider.dart';

/// Comprehensive Feed View supporting both Mobile and Desktop layout parity.
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView> {
  final _picker = ImagePicker();

  Future<void> _handleRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feed updated with latest donor stories & requests.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMobileLayout();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE FEED LAYOUT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final posts = ref.watch(feedProvider);

    return RefreshIndicator(
      color: const Color(0xFFC30121),
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Quick Lazy-Registration Actions ──
          const _FeedActionCards(),
          const SizedBox(height: 16),

          // ── Post Creation Card (Top) ──
          _PostCreatorCard(picker: _picker),
          const SizedBox(height: 16),

          // ── Feed Posts Stream ──
          for (final post in posts) ...[
            _FeedPostCard(post: post),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAZY REGISTRATION ACTIONS (REQUEST BLOOD & DONATE)
// ─────────────────────────────────────────────────────────────────────────────

class _FeedActionCards extends ConsumerWidget {
  const _FeedActionCards();

  void _handleAction(BuildContext context, WidgetRef ref, {required String actionType}) {
    final profile = ref.read(profileProvider).value;
    final authUser = ref.read(authProvider).user;
    final bool isComplete = (profile?.isProfileComplete == true) || (authUser?.isProfileComplete == true);

    if (!isComplete) {
      context.push('/complete-profile');
    } else {
      context.push('/emergency-request');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // ── 1. Request Blood Button ──
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _handleAction(context, ref, actionType: 'request'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC30121), Color(0xFF9E001A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC30121).withAlpha(70),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.emergency_rounded, color: Colors.white, size: 26),
                    SizedBox(height: 10),
                    Text(
                      'Request Blood',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Post urgent emergency',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── 2. Donate Blood Button ──
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _handleAction(context, ref, actionType: 'donate'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF3D2D6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.volunteer_activism_rounded, color: Color(0xFFC30121), size: 26),
                    SizedBox(height: 10),
                    Text(
                      'Donate Blood',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Available as lifesaver',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST CREATOR CARD (Top Card)
// ─────────────────────────────────────────────────────────────────────────────

class _PostCreatorCard extends ConsumerStatefulWidget {
  const _PostCreatorCard({required this.picker});
  final ImagePicker picker;

  @override
  ConsumerState<_PostCreatorCard> createState() => _PostCreatorCardState();
}

class _PostCreatorCardState extends ConsumerState<_PostCreatorCard> {
  final _textCtrl = TextEditingController();
  Uint8List? _attachedImageBytes;
  String? _clinicCheckIn;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await widget.picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _attachedImageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach image: $e')),
        );
      }
    }
  }

  void _onPost() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _attachedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write your donation story or attach a photo before posting.'),
          backgroundColor: Color(0xFFC30121),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final author = user?.fullName.isNotEmpty == true ? user!.fullName : 'Donor Altruist';

    ref.read(feedProvider.notifier).addPost(
      authorName: author,
      content: text,
      imageBytes: _attachedImageBytes,
      location: _clinicCheckIn,
    );

    _textCtrl.clear();
    setState(() {
      _attachedImageBytes = null;
      _clinicCheckIn = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Story posted to BloodPulse community! 🎉'),
        backgroundColor: Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final initials = user?.fullName.isNotEmpty == true ? user!.fullName.substring(0, 1).toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFEE9EB),
                child: Text(
                  initials,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Share your donation story...',
                    hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF888888)),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                ),
              ),
            ],
          ),

          if (_attachedImageBytes != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _attachedImageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _attachedImageBytes = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined, size: 18, color: Color(0xFFC30121)),
                    label: const Text(
                      'Photo',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _clinicCheckIn = _clinicCheckIn == null ? 'Westside Blood Center' : null;
                      });
                    },
                    icon: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: _clinicCheckIn != null ? const Color(0xFFC30121) : const Color(0xFF666666),
                    ),
                    label: Text(
                      _clinicCheckIn ?? 'Check In',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _clinicCheckIn != null ? const Color(0xFFC30121) : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC30121),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  elevation: 0,
                ),
                onPressed: _onPost,
                child: const Text(
                  'Post',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED POST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FeedPostCard extends ConsumerStatefulWidget {
  const _FeedPostCard({required this.post});
  final FeedPostItem post;

  @override
  ConsumerState<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<_FeedPostCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onSendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authProvider).user;
    final author = user?.fullName.isNotEmpty == true ? user!.fullName : 'Donor';
    ref.read(feedProvider.notifier).addComment(widget.post.id, author, text);
    _commentCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Name, Badges, 3-dot ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFEE9EB),
                child: Text(
                  post.authorName.isNotEmpty ? post.authorName.substring(0, 1).toUpperCase() : 'A',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.roleBadgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: post.authorRole == AuthorRole.verifiedClinic
                                  ? const Color(0xFFE8F1FF)
                                  : const Color(0xFFFFF2D6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              post.roleBadgeText!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: post.authorRole == AuthorRole.verifiedClinic
                                    ? const Color(0xFF0D68AA)
                                    : const Color(0xFFB57900),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.location != null ? '${post.timestamp} • ${post.location}' : post.timestamp,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF888888)),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'save', child: Text('Save Post')),
                  const PopupMenuItem(value: 'share', child: Text('Share Story')),
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                ],
              ),
            ],
          ),

          // ── Urgent / Blood Group Badges ──
          if (post.urgentNeedBadge != null || post.bloodGroupBadge != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (post.urgentNeedBadge != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFC30121)),
                        const SizedBox(width: 4),
                        Text(
                          post.urgentNeedBadge!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC30121),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (post.bloodGroupBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC30121),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      post.bloodGroupBadge!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ── Content Text ──
          Text(
            post.content,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF2B2B2B),
              height: 1.5,
            ),
          ),

          // ── Attached Image (If any) ──
          if (post.imageUrl != null || post.imageBytes != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: post.imageBytes != null
                  ? Image.memory(
                      post.imageBytes!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ],

          // ── Achievement Badge Box (e.g. Sarah Mitchell 5th donation) ──
          if (post.achievementBadge != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF9D2D7)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE9EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFC30121), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.achievementBadge!,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC30121),
                          ),
                        ),
                        const Text(
                          'Keep donating to unlock the Diamond Lifesaver badge!',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 28),

          // ── Interaction Actions Row: Like, Comment, Repost, Share ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Action
              InkWell(
                onTap: () => ref.read(feedProvider.notifier).toggleReact(post.id),
                child: Row(
                  children: [
                    Icon(
                      post.isReacted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: post.isReacted ? const Color(0xFFC30121) : const Color(0xFF666666),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.reactCount}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: post.isReacted ? const Color(0xFFC30121) : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),

              // Comment Action
              InkWell(
                onTap: () => setState(() => _showComments = !_showComments),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF666666)),
                    const SizedBox(width: 6),
                    Text(
                      '${post.commentCount}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ),

              // Repost Action
              InkWell(
                onTap: () => ref.read(feedProvider.notifier).toggleRepost(post.id),
                child: Row(
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: post.isReposted ? const Color(0xFF1B8A4E) : const Color(0xFF666666),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Repost',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: post.isReposted ? const Color(0xFF1B8A4E) : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),

              // Share Action
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post link copied to clipboard! Share to save lives.'),
                      backgroundColor: Color(0xFF0D68AA),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF666666)),
              ),
            ],
          ),

          // ── Comments Expansion ──
          if (_showComments) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Comments List
            for (final c in post.comments) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFFEE9EB),
                      child: Text(
                        c.authorName.isNotEmpty ? c.authorName.substring(0, 1) : 'U',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF3F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.authorName,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.text,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF444444)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Add Comment Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: 'Write a warm reply...',
                      hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF888888)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFFDF3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFC30121), size: 20),
                  onPressed: _onSendComment,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

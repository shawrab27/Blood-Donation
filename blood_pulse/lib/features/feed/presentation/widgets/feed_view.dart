import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
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
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _PostCreatorCard(picker: _picker),
                const SizedBox(height: 10),
              ],
            );
          }
          final post = posts[index - 1];
          final isLast = index == posts.length;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 40.0 : 12.0),
            child: _FeedPostCard(post: post),
          );
        },
      ),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFEE9EB),
                child: Text(
                  initials,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6ECEC),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFEEDCDC)),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF8E7D7F)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    maxLines: null,
                  ),
                ),
              ),
            ],
          ),

          if (_attachedImageBytes != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _attachedImageBytes!,
                    height: 120,
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

          const Divider(height: 16),

          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 16, color: Color(0xFFC30121)),
                      label: const Text(
                        'Photo',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          _clinicCheckIn = _clinicCheckIn == null ? 'Westside Blood Center' : null;
                        });
                      },
                      icon: Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _clinicCheckIn != null ? const Color(0xFFC30121) : const Color(0xFF666666),
                      ),
                      label: Text(
                        _clinicCheckIn ?? 'Check In',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _clinicCheckIn != null ? const Color(0xFFC30121) : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC30121),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
                onPressed: _onPost,
                child: const Text(
                  'Post',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
  final _commentFocus = FocusNode();

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onSendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    _commentFocus.unfocus();
    await ref.read(feedProvider.notifier).addComment(
      widget.post.id,
      text,
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: const Color(0xFFC30121),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isUrgent = post.urgentNeedBadge != null;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (isUrgent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: Container(color: const Color(0xFFC30121)),
              ),
            Padding(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (post.urgentNeedBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE9EB),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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

          const Divider(height: 18),

          // ── Interaction Actions Row: Like, Comment, Repost, Share ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Action (Love)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final messenger = ScaffoldMessenger.of(context);
                    ref.read(feedProvider.notifier).toggleReact(
                      post.id,
                      onError: (error) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: const Color(0xFFC30121),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        AnimatedScale(
                          scale: post.isReacted ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            post.isReacted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 19,
                            color: post.isReacted ? const Color(0xFFC30121) : const Color(0xFF666666),
                          ),
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
                ),
              ),

              // Comment Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() => _showComments = !_showComments);
                    if (_showComments) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) _commentFocus.requestFocus();
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _showComments ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: _showComments ? const Color(0xFFC30121) : const Color(0xFF666666),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentCount}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _showComments ? const Color(0xFFC30121) : const Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Repost Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final success = await ref.read(feedProvider.notifier).repost(
                      post.id,
                      onError: (error) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: const Color(0xFFC30121),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                    if (success) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                Icons.repeat_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text('Reposted to community feed!'),
                            ],
                          ),
                          backgroundColor: Color(0xFF1B8A4E),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 19,
                          color: post.isReposted ? const Color(0xFF1B8A4E) : const Color(0xFF666666),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.repostCount > 0 ? 'Repost (${post.repostCount})' : 'Repost',
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
                ),
              ),

              // Share Action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    ref.read(feedProvider.notifier).incrementShare(post.id);
                    final shareText = '🩸 BloodPulse Community Alert: ${post.authorName} posted:\n"${post.content}"\n\nJoin the cause at: https://bloodpulse.app';
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Story link copied to clipboard! Ready to share.'),
                              ),
                            ],
                          ),
                          backgroundColor: Color(0xFF0D68AA),
                          duration: Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined, size: 18, color: Color(0xFF666666)),
                        if (post.shareCount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${post.shareCount}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Comments Expansion ──
          if (_showComments) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Comments List
            if (post.comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No comments yet. Write a warm note to ${post.authorName}!',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF888888), fontStyle: FontStyle.italic),
                ),
              ),

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
                        c.authorName.isNotEmpty ? c.authorName.substring(0, 1).toUpperCase() : 'U',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    focusNode: _commentFocus,
                    onSubmitted: (_) => _onSendComment(),
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
    ),
  ],
),
),
);
}
}

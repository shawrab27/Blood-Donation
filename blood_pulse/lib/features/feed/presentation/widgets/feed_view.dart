import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/feed_provider.dart';

/// The full responsive Feed Tab implementation.
class FeedView extends ConsumerWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);

    return ResponsiveLayout(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Interactive Post / Story Creator Container ─────────────────────
          const _PostCreationContainer(),

          const SizedBox(height: 20),

          // ── Feed Header ────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Community Feed',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Feed Posts List ────────────────────────────────────────────────
          ...posts.map((post) => _FeedPostCard(post: post)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST CREATOR CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

class _PostCreationContainer extends ConsumerWidget {
  const _PostCreationContainer();

  void _openComposer(BuildContext context, WidgetRef ref, {String? defaultOption}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PostComposerModal(initialOption: defaultOption),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Row with Avatar + Creator Input Bar
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF3DDE0),
                  child: Text(
                    auth.user?.fullName.isNotEmpty == true
                        ? auth.user!.fullName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openComposer(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF3F3),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Text(
                        'Share a blood request or update...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.neutral,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Quick Options Bar: Image, Text, Feeling, Check-in
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickOptionButton(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    color: const Color(0xFF1B8A4E),
                    onTap: () => _openComposer(context, ref, defaultOption: 'Image'),
                  ),
                  const SizedBox(width: 12),
                  _QuickOptionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'Text',
                    color: AppColors.tertiary,
                    onTap: () => _openComposer(context, ref, defaultOption: 'Text'),
                  ),
                  const SizedBox(width: 12),
                  _QuickOptionButton(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    label: 'Feeling',
                    color: const Color(0xFFE65100),
                    onTap: () => _openComposer(context, ref, defaultOption: 'Feeling'),
                  ),
                  const SizedBox(width: 12),
                  _QuickOptionButton(
                    icon: Icons.location_on_outlined,
                    label: 'Check-in',
                    color: AppColors.primary,
                    onTap: () => _openComposer(context, ref, defaultOption: 'Check-in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickOptionButton extends StatelessWidget {
  const _QuickOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST COMPOSER MODAL
// ─────────────────────────────────────────────────────────────────────────────

class _PostComposerModal extends ConsumerStatefulWidget {
  const _PostComposerModal({this.initialOption});

  final String? initialOption;

  @override
  ConsumerState<_PostComposerModal> createState() => _PostComposerModalState();
}

class _PostComposerModalState extends ConsumerState<_PostComposerModal> {
  final _contentCtrl = TextEditingController();
  String? _selectedFeeling;
  String? _selectedLocation;
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialOption == 'Feeling') {
      _selectedFeeling = 'Feeling Hopeful 💖';
    } else if (widget.initialOption == 'Check-in') {
      _selectedLocation = 'Dhaka Medical College Hospital';
    } else if (widget.initialOption == 'Image') {
      _hasImage = true;
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _onPublish() {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty && !_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text or select an attachment.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = ref.read(authProvider);
    final name = auth.user?.fullName.isNotEmpty == true ? auth.user!.fullName : 'Verified Altruist';

    ref.read(feedProvider.notifier).addPost(
          authorName: name,
          content: text.isEmpty ? 'Updated status post' : text,
          feeling: _selectedFeeling,
          location: _selectedLocation,
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Post published to Community Feed!', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create Post',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 14),

          // Metadata Chips (Feeling / Location)
          Wrap(
            spacing: 8,
            children: [
              if (_selectedFeeling != null)
                Chip(
                  label: Text(_selectedFeeling!),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _selectedFeeling = null),
                ),
              if (_selectedLocation != null)
                Chip(
                  label: Text('📍 $_selectedLocation'),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _selectedLocation = null),
                ),
              if (_hasImage)
                Chip(
                  label: const Text('📷 Image Attached'),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _hasImage = false),
                ),
            ],
          ),
          if (_selectedFeeling != null || _selectedLocation != null || _hasImage) const SizedBox(height: 10),

          // Main Content Text
          CustomInputField(
            controller: _contentCtrl,
            hint: 'What is on your mind? Share an emergency request or donation story...',
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          // Quick Toggles inside composer
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.image_outlined, color: _hasImage ? AppColors.primary : AppColors.neutral),
                onPressed: () => setState(() => _hasImage = !_hasImage),
              ),
              IconButton(
                icon: Icon(Icons.sentiment_satisfied_alt_rounded, color: _selectedFeeling != null ? AppColors.primary : AppColors.neutral),
                onPressed: () => setState(() => _selectedFeeling = _selectedFeeling == null ? 'Feeling Grateful 🙏' : null),
              ),
              IconButton(
                icon: Icon(Icons.location_on_outlined, color: _selectedLocation != null ? AppColors.primary : AppColors.neutral),
                onPressed: () => setState(() => _selectedLocation = _selectedLocation == null ? 'Dhaka Medical College' : null),
              ),
              const Spacer(),
              CapsuleButton(
                label: 'Post',
                icon: Icons.send_rounded,
                onPressed: _onPublish,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED POST CARD (WITH REACT, COMMENT, REPOST INTERACTIONS)
// ─────────────────────────────────────────────────────────────────────────────

class _FeedPostCard extends ConsumerWidget {
  const _FeedPostCard({required this.post});

  final FeedPostItem post;

  void _openCommentsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommentsThreadModal(post: post),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Author Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFF3DDE0),
                  child: Text(
                    post.authorName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                          if (post.authorBloodGroup != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFFF0F1), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                post.authorBloodGroup!,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(post.timestamp, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                          if (post.location != null) ...[
                            const Text(' • ', style: TextStyle(color: AppColors.neutral)),
                            Icon(Icons.location_on, size: 12, color: AppColors.tertiary),
                            const SizedBox(width: 2),
                            Text(post.location!, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.tertiary)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.urgencyBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: post.urgencyBadge == 'Critical' ? const Color(0xFFFFECEE) : const Color(0xFFEDF4FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      post.urgencyBadge!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: post.urgencyBadge == 'Critical' ? AppColors.primary : AppColors.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Feeling Tag
            if (post.feeling != null) ...[
              Text(
                post.feeling!,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tertiary),
              ),
              const SizedBox(height: 6),
            ],

            // Content
            Text(
              post.content,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.secondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Interaction Bar: React | Comment | Repost (Loop Arrow Symbol)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. REACT (Like/Love with counter)
                InkWell(
                  onTap: () => ref.read(feedProvider.notifier).toggleReact(post.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          post.isReacted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 20,
                          color: post.isReacted ? AppColors.primary : AppColors.neutral,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.reactCount}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: post.isReacted ? AppColors.primary : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. COMMENT (Comment with counter & thread trigger)
                InkWell(
                  onTap: () => _openCommentsModal(context, ref),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.mode_comment_outlined, size: 20, color: AppColors.neutral),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentCount}',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. REPOST (Loop/Recycling Arrow Symbol strictly: Icons.repeat_rounded)
                InkWell(
                  onTap: () {
                    ref.read(feedProvider.notifier).toggleRepost(post.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          post.isReposted ? 'Repost removed' : '🔄 Reposted to your community feed!',
                          style: const TextStyle(fontFamily: 'Inter'),
                        ),
                        backgroundColor: AppColors.tertiary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded, // STRICT LOOP/RECYCLING SYMBOL
                          size: 20,
                          color: post.isReposted ? const Color(0xFF1B8A4E) : AppColors.neutral,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.repostCount}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: post.isReposted ? const Color(0xFF1B8A4E) : AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS THREAD MODAL
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsThreadModal extends ConsumerStatefulWidget {
  const _CommentsThreadModal({required this.post});

  final FeedPostItem post;

  @override
  ConsumerState<_CommentsThreadModal> createState() => _CommentsThreadModalState();
}

class _CommentsThreadModalState extends ConsumerState<_CommentsThreadModal> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onSendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final auth = ref.read(authProvider);
    final name = auth.user?.fullName.isNotEmpty == true ? auth.user!.fullName : 'Altruistic Member';

    ref.read(feedProvider.notifier).addComment(widget.post.id, name, text);
    _commentCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Re-watch active post from provider for live updates
    final posts = ref.watch(feedProvider);
    final updatedPost = posts.firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      height: MediaQuery.sizeOf(context).height * 0.65,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            'Comments (${updatedPost.commentCount})',
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 16),

          // Comments List
          Expanded(
            child: updatedPost.comments.isEmpty
                ? const Center(
                    child: Text('No comments yet. Be the first to comment!', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
                  )
                : ListView.builder(
                    itemCount: updatedPost.comments.length,
                    itemBuilder: (ctx, idx) {
                      final c = updatedPost.comments[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFF3DDE0),
                              child: Text(c.authorName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDF3F3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(c.authorName, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                        Text(c.timestamp, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.neutral)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.text, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),

          // Input Row
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _commentCtrl,
                  hint: 'Write a comment...',
                  onSubmitted: (_) => _onSendComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                onPressed: _onSendComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

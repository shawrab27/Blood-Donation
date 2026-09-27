// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../feed/presentation/providers/feed_provider.dart';

class SocialFeedScreen extends ConsumerWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);

    return Scaffold(
      appBar: CustomAppBar(
        showLogo: true,
        showBackButton: true,
        onBack: () => context.go('/dashboard'),
      ),
      body: posts.isEmpty
          ? const Center(child: Text('No posts found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppConstants.padding),
              itemCount: posts.length + 2, // stories + header + posts
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stories of Impact', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                if (index == 1) {
                  return SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildStoryBubble(context, isNew: true, label: 'Add Story', icon: Icons.add),
                      ],
                    ),
                  );
                }
                final post = posts[index - 2];
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.0, top: (index == 2) ? 24.0 : 0.0),
                  child: _buildFeedPost(
                    context,
                    author: post.authorName,
                    time: post.timestamp,
                    content: post.content,
                    likes: post.reactCount,
                    isEmergency: post.urgentNeedBadge != null,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStoryBubble(BuildContext context, {required String label, bool isNew = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isNew ? AppColors.primaryRed : Colors.grey.shade300, width: 3),
              color: isNew ? AppColors.primaryRed.withValues(alpha: 0.1) : AppColors.secondaryNavy,
            ),
            child: icon != null
                ? Icon(icon, color: AppColors.primaryRed)
                : const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFeedPost(BuildContext context, {required String author, required String time, required String content, required int likes, required bool isEmergency}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.secondaryNavy,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                if (isEmergency)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.critical, borderRadius: BorderRadius.circular(12)),
                    child: const Text('EMERGENCY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(content, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.favorite, color: AppColors.primaryRed, size: 20),
                const SizedBox(width: 4),
                Text('$likes', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.comment, color: Colors.grey, size: 20),
                const SizedBox(width: 4),
                Text('Reply', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const Spacer(),
                const Icon(Icons.share, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/feed/presentation/providers/feed_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

new_notifier = '''
class FeedNotifier extends StateNotifier<AsyncValue<List<FeedPostItem>>> {
  FeedNotifier() : super(const AsyncValue.loading()) {
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      state = const AsyncValue.loading();
      final response = await ApiClient().get('posts/');
      if (response.statusCode == 200) {
        import 'dart:convert';
        final List<dynamic> data = jsonDecode(response.body);
        final posts = data.map((item) => FeedPostItem(
          id: item['id'].toString(),
          authorName: item['author_name'] ?? 'Unknown',
          timestamp: item['created_at'] ?? '',
          content: item['text_content'] ?? '',
          reactCount: item['reactions_count'] ?? 0,
          commentCount: item['comments_count'] ?? 0,
          bloodGroupBadge: item['author_blood_group'],
          postType: 'general',
        )).toList();
        state = AsyncValue.data(posts);
      } else {
        state = AsyncValue.error('Failed to load posts', StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void addPost(FeedPostItem post) {}
  void toggleReact(String postId) {}
  void addComment(String postId, FeedComment comment) {}
  void repost(String postId, String reposterName) {}
}
'''

import re
content = re.sub(r'class FeedNotifier extends StateNotifier<List<FeedPostItem>> \{.*', new_notifier, content, flags=re.DOTALL)
content = content.replace("StateNotifierProvider<FeedNotifier, List<FeedPostItem>>", "StateNotifierProvider<FeedNotifier, AsyncValue<List<FeedPostItem>>>")
content = "import '../../../../services/api_client.dart';\n" + content

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

import os

filepath = 'lib/features/feed/presentation/providers/feed_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

# We will replace the FeedNotifier constructor and add fetchPosts
new_notifier = '''
import 'dart:convert';
import '../../../../services/api_client.dart';

class FeedNotifier extends StateNotifier<List<FeedPostItem>> {
  final ApiClient _apiClient = ApiClient();

  FeedNotifier() : super([]) {
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final response = await _apiClient.get('posts/');
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
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
        state = posts;
      }
    } catch (e) {
      debugPrint('[FeedNotifier] Error fetching posts: \');
    }
  }

  // Keep the rest of the existing methods below by just replacing the constructor and top parts.
'''

# Wait, instead of replacing the whole thing, let's just insert fetchPosts inside the existing FeedNotifier.

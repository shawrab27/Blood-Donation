import os
import re

filepath = 'lib/features/feed/presentation/providers/feed_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# First, insert imports at the top
content = "import 'dart:convert';\nimport '../../../../services/api_client.dart';\n" + content

# Replace FeedNotifier() : super(_initialPosts); with our fetching logic
fetch_logic = '''FeedNotifier() : super([]) {
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final response = await ApiClient().get('posts/');
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
'''
content = re.sub(r'FeedNotifier\(\) : super\(_initialPosts\);', fetch_logic, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated feed_provider.dart")

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/feed/presentation/providers/feed_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
content = re.sub(
    r'final List<dynamic> data = jsonDecode\(response\.body\);.*?(?=state = AsyncValue\.data\(posts\);)',
    '''final Map<String, dynamic> decoded = jsonDecode(response.body);
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
        ''',
    content, flags=re.DOTALL
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

import os
import re

filepath = 'lib/features/feed/presentation/providers/feed_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Constructor
content = re.sub(
    r'FeedNotifier\(\) : super\(_initialPosts\);',
    r'FeedNotifier() : super([]) { fetchPosts(); }',
    content
)

# 2. Pagination fix
old_json_logic = "final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;"
new_json_logic = '''final Map<String, dynamic> decoded = jsonDecode(response.body);
        final List<dynamic> list = decoded.containsKey('results') ? decoded['results'] : decoded;'''
content = content.replace(old_json_logic, new_json_logic)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

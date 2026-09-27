import os

filepath = 'lib/features/feed/presentation/providers/feed_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re
# Remove the duplicate fetchPosts method
# It starts with "Future<void> fetchPosts() async {" and goes to the next method or end of class
parts = content.split("  Future<void> fetchPosts() async {")
if len(parts) > 2:
    # First part is before first fetchPosts. Second part is first fetchPosts body. Third part is second fetchPosts body.
    # Actually let's just delete the second one.
    # The second one starts at parts[2]
    end_of_duplicate = parts[2].find("  void addPost")
    if end_of_duplicate == -1:
        end_of_duplicate = parts[2].find("  void toggleReact")
    if end_of_duplicate != -1:
        parts[2] = parts[2][end_of_duplicate:]
    content = parts[0] + "  Future<void> fetchPosts() async {" + parts[1] + parts[2]
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Removed duplicate")

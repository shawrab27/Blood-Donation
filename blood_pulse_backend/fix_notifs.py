# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/notifications/presentation/screens/notification_center_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

# We will replace the entire _buildNotificationList function body.
new_func = '''  Widget _buildNotificationList(Box? box) {
    final cachedWidgets = _getCachedNotificationWidgets(box);

    if (_selectedFilterIndex == 2) {
      return _buildMessagesTab(cachedWidgets);
    }

    if (cachedWidgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: cachedWidgets,
    );
  }'''

content = re.sub(r'  Widget _buildNotificationList\(Box\? box\) \{.*?(?=  List<Widget> _getCachedNotificationWidgets)', new_func + '\n\n', content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Replaced!")

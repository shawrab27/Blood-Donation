# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/profile/domain/providers/profile_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

new_fetch = '''  Future<void> fetchProfile() async {
    try {
      state = const AsyncValue.loading();
      final response = await ApiClient().get('donors/me/');
      if (response.statusCode == 200) {
        import 'dart:convert';
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = ProfileModel.fromJson(data);
        state = AsyncValue.data(profile);
      } else if (response.statusCode == 404) {
        state = const AsyncValue.data(null);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }'''

import re
content = re.sub(r'  Future<void> fetchProfile\(\) async \{.*?(?=  Future<bool> updateProfile)', new_fetch + '\n\n', content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

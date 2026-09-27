# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/views/profile/profile_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

import re

old_tab_3 = '''                      // Tab 3: Donation History Log
                      ListView(
                        physics: const BouncingScrollPhysics(),
                        children: const [
                          _ActivityTile(
                            icon: Icons.verified_rounded,
                            color: AppColors.success,
                            title: 'General Hospital',
                            subtitle: '10 June 2026 \u2022 1 Bag (O+)',
                            status: 'Verified Badge',
                          ),
                          _ActivityTile(
                            icon: Icons.verified_rounded,
                            color: AppColors.success,
                            title: 'Bangabandhu Sheikh Mujib Med. University',
                            subtitle: '10 Feb 2026 \u2022 1 Bag (O+)',
                            status: 'Verified Badge',
                          ),
                        ],
                      ),'''

new_tab_3 = '''                      // Tab 3: Donation History Log
                      Consumer(
                        builder: (context, ref, child) {
                          final profileAsync = ref.watch(profileProvider);
                          return profileAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            error: (err, st) => Center(child: Text('Error loading history')),
                            data: (profile) {
                              final history = profile?.donationHistory ?? [];
                              if (history.isEmpty) {
                                return const Center(child: Text('No donation history yet', style: TextStyle(color: Colors.grey)));
                              }
                              return ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: history.length,
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return _ActivityTile(
                                    icon: Icons.verified_rounded,
                                    color: AppColors.success,
                                    title: item.location,
                                    subtitle: '\ • \ Bag(s)',
                                    status: item.notes ?? 'Verified',
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),'''

if old_tab_3 in content:
    content = content.replace(old_tab_3, new_tab_3)
    # also we need to import the provider!
    if "import '../../features/profile/domain/providers/profile_provider.dart';" not in content:
        content = "import '../../features/profile/domain/providers/profile_provider.dart';\n" + content
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced!")
else:
    print("Failed to find exact block")

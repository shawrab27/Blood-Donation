# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = '../blood_pulse/lib/features/blood_hub/presentation/widgets/blood_hub_view.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

start = "Widget _buildDonorSearchSection() {"
end = "Widget _buildSearchFilterCard(DonorSearchFilter filter) {"

if start in content and end in content:
    pre = content[:content.find(start)]
    post = content[content.find(end):]
    
    new_code = '''Widget _buildDonorSearchSection() {
    final donorsAsync = ref.watch(filteredDonorsProvider);
    final filter = ref.watch(donorSearchFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchFilterCard(filter),
        const SizedBox(height: 20),
        donorsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, st) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(12)),
            child: Text('Error loading donors: \', style: const TextStyle(color: Colors.red)),
          ),
          data: (donors) {
            if (donors.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No donors found for your criteria.', style: TextStyle(color: Colors.grey)),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Donors (\ found)',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                ),
                const SizedBox(height: 12),
                for (final donor in donors) ...[
                  _buildDonorCard(donor),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 20),
                _buildLiveMapContainer(donors),
              ],
            );
          },
        ),
      ],
    );
  }

  '''
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(pre + new_code + post)
    print("Replaced!")

import os
import re

filepath = 'lib/features/health_hub/presentation/screens/health_accessories_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../domain/providers/health_hub_provider.dart';")

# 2. Convert to ConsumerStatefulWidget
content = content.replace("class HealthAccessoriesScreen extends StatefulWidget", "class HealthAccessoriesScreen extends ConsumerStatefulWidget")
content = content.replace("State<HealthAccessoriesScreen> createState() => _HealthAccessoriesScreenState();", "ConsumerState<HealthAccessoriesScreen> createState() => _HealthAccessoriesScreenState();")
content = content.replace("class _HealthAccessoriesScreenState extends State<HealthAccessoriesScreen>", "class _HealthAccessoriesScreenState extends ConsumerState<HealthAccessoriesScreen>")

# 3. Setup build method opening
old_build_start = '''  @override
  Widget build(BuildContext context) {
    final filteredItems = HealthAccessory.curatedList.where((item) {'''

new_build_start = '''  @override
  Widget build(BuildContext context) {
    final asyncAccessories = ref.watch(healthAccessoriesProvider);
    return asyncAccessories.when(
      loading: () => const Scaffold(backgroundColor: Color(0xFFFFF8F7), body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(backgroundColor: Color(0xFFFFF8F7), body: Center(child: Text('Error loading accessories', style: TextStyle(fontFamily: 'Inter')))),
      data: (items) {
        final filteredItems = items.where((item) {'''

content = content.replace(old_build_start, new_build_start)

# 4. Setup build method closing
old_build_end = '''            ],
          ),
        ),
      ),
    );
  }

  void _openAccessoryDetails(HealthAccessory item) {'''

new_build_end = '''            ],
          ),
        ),
      ),
    );
      },
    );
  }

  void _openAccessoryDetails(HealthAccessory item) {'''

content = content.replace(old_build_end, new_build_end)

# 5. Update disclosure text
old_disclaimer = "'Products listed are curated from verified pharmacy partners. A modest referral commission supports BloodPulse voluntary emergency blood dispatch logistics at no extra cost to you.'"
new_disclaimer = "'Products listed are curated from verified pharmacy partners. Sponsored — BloodPulse may earn a commission from purchases. (স্পন্সরড — কেনাকাটা থেকে BloodPulse কমিশন পেতে পারে)'"
content = content.replace(old_disclaimer, new_disclaimer)

# 6. Change price range label to be clearly approximate
# In _buildAccessoryCard, we have Text(item.priceRange, style: ...)
# Let's search for how it's used.
content = content.replace("item.priceRange,", "'Approx. ',")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Screen updated")

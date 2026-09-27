import re

with open('lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

old_text = "Products listed are curated from verified pharmacy partners. Sponsored — BloodPulse may earn a commission from purchases. (স্পন্সরড — কেনাকাটা থেকে BloodPulse কমিশন পেতে পারে)"
new_text = "These are general product search links, not endorsements from specific sellers. Sponsored — BloodPulse may earn a commission from purchases. (এগুলো সাধারণ পণ্য অনুসন্ধানের লিংক, নির্দিষ্ট কোনো বিক্রেতার অনুমোদন নয়। স্পন্সরড — কেনাকাটা থেকে BloodPulse কমিশন পেতে পারে - unreviewed)"

text = text.replace(old_text, new_text)

with open('lib/features/health_hub/presentation/screens/health_accessories_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print("Disclosure updated.")

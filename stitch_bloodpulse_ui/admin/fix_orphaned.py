import re

with open('trust-fraud-engine.html', 'r', encoding='utf-8') as f:
    content = f.read()

# The orphaned code to remove:
orphaned_code = """
        if (confirm('Permanently ban this user? This will soft-delete their profile, wipe PII, and prevent login.')) {
            actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/users/${userId}/ban/`, null);
        }
    }
"""

# Replace it with empty string
content = content.replace(orphaned_code, "")

# And just in case there's slight whitespace difference, use regex
content = re.sub(r'\s*if \(confirm\(\'Permanently ban this user\? This will soft-delete their profile, wipe PII, and prevent login\.\'\)\) \{\s*actionRequest\(`http://127\.0\.0\.1:8000/api/admin/trust-engine/users/\$\{userId\}/ban/`, null\);\s*\}\s*\}', '', content)


with open('trust-fraud-engine.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Removed orphaned code block!")

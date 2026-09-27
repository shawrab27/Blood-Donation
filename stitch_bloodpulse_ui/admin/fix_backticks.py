import sys

with open('trust-fraud-engine.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'data.map(item => \n        <div class="p-4 hover:bg-[#FAF0F0]',
    'data.map(item => `\n        <div class="p-4 hover:bg-[#FAF0F0]'
)
content = content.replace(
    ' Ban</button>\n            </div>\n        </div>\n        ).join(\'\');\n    }',
    ' Ban</button>\n            </div>\n        </div>\n        `).join(\'\');\n    }'
)

with open('trust-fraud-engine.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed backticks!")

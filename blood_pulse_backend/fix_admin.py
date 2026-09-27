# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os

filepath = 'api/admin.py'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("DonationHistory, RecentLog", "DonationHistory, RecentLog, HealthAccessory")

admin_config = '''
@admin.register(HealthAccessory)
class HealthAccessoryAdmin(admin.ModelAdmin):
    list_display = ('name_en', 'category', 'is_active', 'display_order', 'price_range_text')
    list_filter = ('category', 'is_active')
    search_fields = ('name_en', 'name_bn')
    list_editable = ('is_active', 'display_order')
'''

content += admin_config

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

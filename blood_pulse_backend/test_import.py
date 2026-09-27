# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import csv
import os
import django
import sys

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from assistant.models import KBEntry
from assistant.embeddings import get_embedding
from django.utils import timezone
from datetime import datetime

csv_path = r"..\docs\bloodhub\bloodpulse_kb_v1.csv"
print(f"Reading {csv_path}")

with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)
    print(f"Total rows to process: {len(rows)}")

KBEntry.objects.all().delete()
print("Cleared old KB entries")

count = 0
for row in rows:
    body_en = row['body_en'].strip()
    print(f"Processing row {count+1}: {body_en[:30]}...")
    emb = get_embedding(body_en) if body_en else None
    
    rev_date = row.get('reviewed_at')
    dt_obj = None
    if rev_date:
        try:
            dt_obj = timezone.make_aware(datetime.strptime(rev_date, '%Y-%m-%d'))
        except:
            pass
    
    KBEntry.objects.create(
        category=row.get('category', ''),
        title_en=row.get('title_en', ''),
        title_bn=row.get('title_bn', ''),
        body_en=body_en,
        body_bn=row.get('body_bn', ''),
        tags=row.get('tags', ''),
        source_name=row.get('source_name', ''),
        source_url=row.get('source_url', ''),
        reviewed_at=dt_obj,
        status=row.get('status', 'APPROVED'),
        embedding=emb
    )
    count += 1
    print(f"Inserted row {count}")
    sys.stdout.flush()

print(f"Done processing {count} rows")

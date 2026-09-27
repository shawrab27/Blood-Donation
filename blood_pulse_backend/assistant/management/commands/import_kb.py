# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import csv
import os
from django.core.management.base import BaseCommand
from assistant.models import KBEntry
from assistant.embeddings import get_embedding
from django.utils import timezone
from datetime import datetime

class Command(BaseCommand):
    help = 'Imports KB entries from CSV'

    def add_arguments(self, parser):
        parser.add_argument('csv_path', type=str, help='Path to the CSV file')

    def handle(self, *args, **options):
        csv_path = options['csv_path']
        if not os.path.exists(csv_path):
            self.stderr.write(self.style.ERROR(f'File not found: {csv_path}'))
            return
            
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            count = 0
            # Clear previous entries first
            KBEntry.objects.all().delete()
            for row in reader:
                # Generate embedding from body_en
                body_en = row['body_en'].strip()
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
                if count % 5 == 0:
                    self.stdout.write(f'Imported {count} rows...')
                    
            self.stdout.write(self.style.SUCCESS(f'Successfully imported {count} KB entries'))

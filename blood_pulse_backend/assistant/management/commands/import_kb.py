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
        parser.add_argument('--clear', action='store_true', help='Clear existing KB entries before importing')

    def handle(self, *args, **options):
        csv_path = options['csv_path']
        if not os.path.exists(csv_path):
            self.stderr.write(self.style.ERROR(f'File not found: {csv_path}'))
            return
            
        if options.get('clear'):
            self.stdout.write("Clearing existing KB entries...")
            KBEntry.objects.all().delete()

        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = list(csv.DictReader(f))
            count = 0
            for row in reader:
                is_addon = 'question_en' in row
                row_id = int(row['id']) if 'id' in row and str(row['id']).isdigit() else None
                title_en = row['question_en'] if is_addon else row.get('title_en', '')
                title_bn = row['question_bn'] if is_addon else row.get('title_bn', '')
                body_en = (row['answer_en'] if is_addon else row.get('body_en', '')).strip()
                body_bn = (row['answer_bn'] if is_addon else row.get('body_bn', '')).strip()
                category = row.get('category', '')
                source_name = row['source'] if is_addon else row.get('source_name', '')
                source_url = row.get('source_url', '')
                status = ('APPROVED' if str(row.get('verified', '')).strip().lower() == 'true' else 'DRAFT') if is_addon else row.get('status', 'APPROVED')

                # Check if entry already has embedding
                existing = KBEntry.objects.filter(id=row_id).first() if row_id else None
                emb = existing.embedding if existing and existing.embedding else (get_embedding(body_en) if body_en else None)

                defaults = {
                    'category': category,
                    'title_en': title_en,
                    'title_bn': title_bn,
                    'body_en': body_en,
                    'body_bn': body_bn,
                    'source_name': source_name,
                    'source_url': source_url,
                    'status': status,
                    'embedding': emb,
                }
                
                if row_id:
                    KBEntry.objects.update_or_create(id=row_id, defaults=defaults)
                else:
                    KBEntry.objects.create(**defaults)
                    
                count += 1
                if count % 10 == 0 or count == len(reader):
                    self.stdout.write(f'Imported {count}/{len(reader)} rows...')
                    
            self.stdout.write(self.style.SUCCESS(f'Successfully imported {count} KB entries'))


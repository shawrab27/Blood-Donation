# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
import csv
import time
import random
from concurrent.futures import ThreadPoolExecutor, as_completed

# Setup Django environment
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
import django
django.setup()

from assistant.models import KBEntry
from assistant.embeddings import get_embedding
from django.db import transaction

def safe_get_embedding(text: str, max_retries=5):
    """Generates a 768-dim embedding with exponential backoff retry on errors."""
    if not text or not text.strip():
        return None
    for attempt in range(max_retries):
        try:
            return get_embedding(text.strip())
        except Exception as e:
            if attempt == max_retries - 1:
                print(f"[ERROR] Embedding failed after {max_retries} attempts: {e}")
                raise e
            wait = (2 ** attempt) + random.uniform(0.5, 1.5)
            print(f"[RETRY] Embedding call failed ({e}). Retrying in {wait:.1f}s...")
            time.sleep(wait)

def migrate_existing_ids():
    """Migrate the existing 21 rows (181..201) to their true canonical IDs 1..21."""
    print("Checking existing rows 181..201...")
    v1_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'docs', 'bloodhub', 'bloodpulse_kb_v1.csv')
    if not os.path.exists(v1_path):
        v1_path = os.path.join('docs', 'bloodhub', 'bloodpulse_kb_v1.csv')
        
    with open(v1_path, 'r', encoding='utf-8') as f:
        v1_rows = list(csv.DictReader(f))
        
    with transaction.atomic():
        for r in v1_rows[:21]:
            target_id = int(r['id'])
            title = r['title_en']
            # Find entry by title or target_id
            existing = KBEntry.objects.filter(id=target_id).first()
            if existing:
                continue
            old_entry = KBEntry.objects.filter(title_en=title).first()
            if old_entry and old_entry.id != target_id:
                old_id = old_entry.id
                KBEntry.objects.filter(id=old_id).update(id=target_id)
                print(f"  Mapped entry '{title[:35]}' from ID {old_id} -> {target_id}")

def ingest_file(csv_path, expected_range=None):
    """Ingests rows from a CSV file, computing embeddings if missing."""
    if not os.path.exists(csv_path):
        print(f"[ERROR] CSV not found: {csv_path}")
        return 0
        
    print(f"\nProcessing {csv_path}...")
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = list(csv.DictReader(f))
        
    print(f"Total rows in CSV: {len(reader)}")
    rows_to_process = []
    
    for row in reader:
        row_id = int(row['id'])
        if expected_range and (row_id < expected_range[0] or row_id > expected_range[1]):
            continue
            
        is_addon = 'question_en' in row
        title_en = row['question_en'] if is_addon else row['title_en']
        title_bn = row['question_bn'] if is_addon else row['title_bn']
        body_en = row['answer_en'] if is_addon else row['body_en']
        body_bn = row['answer_bn'] if is_addon else row['body_bn']
        category = row.get('category', '')
        source_name = row['source'] if is_addon else row.get('source_name', '')
        source_url = row.get('source_url', '')
        
        if is_addon:
            status = 'APPROVED' if str(row.get('verified', '')).strip().lower() == 'true' else 'DRAFT'
        else:
            status = row.get('status', 'APPROVED')
            
        rows_to_process.append({
            'id': row_id,
            'category': category,
            'title_en': title_en,
            'title_bn': title_bn,
            'body_en': body_en,
            'body_bn': body_bn,
            'source_name': source_name,
            'source_url': source_url,
            'status': status,
        })

    # Filter out entries that already exist with non-null embeddings
    needs_embedding = []
    already_saved = 0
    for r in rows_to_process:
        existing = KBEntry.objects.filter(id=r['id']).first()
        if existing and existing.embedding is not None:
            already_saved += 1
        else:
            needs_embedding.append(r)
            
    print(f"Already populated in DB: {already_saved}")
    print(f"Rows needing embedding: {len(needs_embedding)}")
    
    if not needs_embedding:
        return already_saved

    # Concurrently compute embeddings
    print(f"Generating embeddings for {len(needs_embedding)} items (max 3 concurrent)...")
    
    def process_row(r):
        emb = safe_get_embedding(r['body_en'])
        return r, emb

    completed_count = 0
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=3) as pool:
        future_map = {pool.submit(process_row, r): r for r in needs_embedding}
        for future in as_completed(future_map):
            r, emb = future.result()
            KBEntry.objects.update_or_create(
                id=r['id'],
                defaults={
                    'category': r['category'],
                    'title_en': r['title_en'],
                    'title_bn': r['title_bn'],
                    'body_en': r['body_en'],
                    'body_bn': r['body_bn'],
                    'source_name': r['source_name'],
                    'source_url': r['source_url'],
                    'status': r['status'],
                    'embedding': emb,
                }
            )
            completed_count += 1
            if completed_count % 10 == 0 or completed_count == len(needs_embedding):
                print(f"  Progress: {completed_count}/{len(needs_embedding)} embedded & saved ({time.time()-t0:.1f}s)", flush=True)

    print(f"Completed ingestion for {csv_path}. Added/Updated: {completed_count}", flush=True)
    return already_saved + completed_count

def main():
    print("==================================================")
    print("  BLOODPULSE KNOWLEDGE BASE INGESTION PIPELINE  ")
    print("==================================================")
    
    # Step 1: Migrate existing 181..201 IDs to 1..21
    migrate_existing_ids()
    
    # Step 2: Baseline rows (v1 CSV, IDs 1 to 33)
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    v1_csv = os.path.join(root_dir, 'docs', 'bloodhub', 'bloodpulse_kb_v1.csv')
    if not os.path.exists(v1_csv):
        v1_csv = os.path.join('..', 'docs', 'bloodhub', 'bloodpulse_kb_v1.csv')
    ingest_file(v1_csv, expected_range=(1, 33))
    
    # Step 3: Addon rows (110 rows, IDs 34 to 143)
    addon_csv = os.path.join(root_dir, 'data', 'bloodpulse_kb_110_addon.csv')
    if not os.path.exists(addon_csv):
        addon_csv = os.path.join('data', 'bloodpulse_kb_110_addon.csv')
    ingest_file(addon_csv, expected_range=(34, 143))
    
    # Step 4: Verification
    total_count = KBEntry.objects.count()
    approved_count = KBEntry.objects.filter(status='APPROVED').count()
    embedded_count = KBEntry.objects.filter(embedding__isnull=False).count()
    min_id = KBEntry.objects.order_by('id').first().id if total_count else None
    max_id = KBEntry.objects.order_by('-id').first().id if total_count else None
    
    print("\n==================================================")
    print("  VERIFICATION AUDIT")
    print("==================================================")
    print(f"Total KBEntry rows in DB: {total_count}")
    print(f"Approved status rows:     {approved_count}")
    print(f"Embedded 768-dim rows:    {embedded_count}")
    print(f"Min ID: {min_id}, Max ID: {max_id}")
    print("==================================================")

if __name__ == "__main__":
    main()

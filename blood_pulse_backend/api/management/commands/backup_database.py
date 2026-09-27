# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import datetime
from django.core.management.base import BaseCommand
from django.conf import settings
from api.models import AuditLog

class Command(BaseCommand):
    help = 'Backups database to a file and logs to AuditLog'

    def handle(self, *args, **kwargs):
        now = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"db_backup_{now}.sqlite3"
        
        # Simple copy for sqlite (since we use sqlite locally)
        # In prod (Neon/Postgres), pg_dump would be used.
        db_path = settings.DATABASES['default']['NAME']
        
        import shutil
        try:
            shutil.copy2(db_path, filename)
            self.stdout.write(self.style.SUCCESS(f'Successfully backed up database to {filename}'))
            
            # Log to audit
            AuditLog.objects.create(
                action='database_backup',
                object_type='System',
                changes={'filename': filename, 'status': 'success'}
            )
        except Exception as e:
            self.stderr.write(self.style.ERROR(f'Backup failed: {e}'))
            AuditLog.objects.create(
                action='database_backup',
                object_type='System',
                changes={'status': 'failed', 'error': str(e)}
            )

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import sqlite3
import sys
conn = sqlite3.connect('db.sqlite3')
cur = conn.cursor()
try:
    cur.execute("SELECT COUNT(*) FROM assistant_kbentry")
    print('Total KBEntries:', cur.fetchone()[0])
    cur.execute("SELECT COUNT(*) FROM assistant_kbentry WHERE status='APPROVED' AND reviewed_by_id IS NOT NULL")
    print('Approved KBEntries:', cur.fetchone()[0])
except Exception as e:
    print('Error KBEntry:', e)

try:
    cur.execute("SELECT COUNT(*) FROM api_auditlog")
    print('AuditLog entries:', cur.fetchone()[0])
except Exception as e:
    print('Error AuditLog:', e)

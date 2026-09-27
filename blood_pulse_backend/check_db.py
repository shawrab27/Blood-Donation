# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import sqlite3
c = sqlite3.connect('db.sqlite3')
res = c.execute("SELECT id, phone_number, nid_hash FROM api_donorprofile").fetchall()
for r in res: print(r)

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from assistant.embeddings import get_embedding

print("Testing one embedding call...")
res = get_embedding("Hello world!")
print("Length of embedding:", len(res))

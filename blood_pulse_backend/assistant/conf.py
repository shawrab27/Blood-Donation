# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from django.conf import settings

GEMINI_MODEL = os.environ.get('GEMINI_MODEL', getattr(settings, 'GEMINI_MODEL', 'gemini-3.8-flash'))
MAX_MESSAGE_CHARS = int(os.environ.get('ASSISTANT_MAX_MESSAGE_CHARS', 500))
HISTORY_TURNS = int(os.environ.get('ASSISTANT_HISTORY_TURNS', 6))
USER_LIMIT_PER_HOUR = int(os.environ.get('ASSISTANT_USER_LIMIT_PER_HOUR', 20))
USER_LIMIT_PER_DAY = int(os.environ.get('ASSISTANT_USER_LIMIT_PER_DAY', 100))
GLOBAL_DAILY_BUDGET = int(os.environ.get('ASSISTANT_GLOBAL_DAILY_BUDGET', 800))
GEMINI_TIMEOUT_SECONDS = int(os.environ.get('ASSISTANT_GEMINI_TIMEOUT_SECONDS', 15))
MAX_OUTPUT_TOKENS = int(os.environ.get('ASSISTANT_MAX_OUTPUT_TOKENS', 500))
TEMPERATURE = float(os.environ.get('ASSISTANT_TEMPERATURE', 0.2))
CACHE_TTL_DAYS = int(os.environ.get('ASSISTANT_CACHE_TTL_DAYS', 7))
LOG_RETENTION_DAYS = int(os.environ.get('ASSISTANT_LOG_RETENTION_DAYS', 30))
KB_TOKEN_BUDGET = int(os.environ.get('ASSISTANT_KB_TOKEN_BUDGET', 8000))
SUPPORT_CONTACT = os.environ.get('ASSISTANT_SUPPORT_CONTACT', '')

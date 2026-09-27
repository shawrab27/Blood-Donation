# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import hashlib
from django.utils import timezone
import datetime
from assistant.models import AnswerCache
from assistant.conf import CACHE_TTL_DAYS

def generate_cache_key(text: str, language: str, kb_version: str) -> str:
    raw = f"{text.strip().lower()}|{language}|{kb_version}"
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()

def get_cached_answer(text: str, language: str, kb_version: str):
    if "[REDACTED" in text:
        return None
        
    key = generate_cache_key(text, language, kb_version)
    cache_entry = AnswerCache.objects.filter(key_hash=key).first()
    
    if cache_entry:
        if cache_entry.expires_at > timezone.now():
            return cache_entry.answer_json
        else:
            cache_entry.delete()
    return None

def set_cached_answer(text: str, language: str, kb_version: str, answer_json: dict):
    if "[REDACTED" in text:
        return
        
    key = generate_cache_key(text, language, kb_version)
    expires = timezone.now() + datetime.timedelta(days=CACHE_TTL_DAYS)
    
    AnswerCache.objects.update_or_create(
        key_hash=key,
        defaults={
            'language': language,
            'answer_json': answer_json,
            'kb_version': kb_version,
            'expires_at': expires
        }
    )

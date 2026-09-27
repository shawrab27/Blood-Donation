# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.cache import cache
from assistant.conf import MAX_MESSAGE_CHARS, USER_LIMIT_PER_HOUR, USER_LIMIT_PER_DAY, GLOBAL_DAILY_BUDGET
import datetime

class LimitsExceeded(Exception):
    def __init__(self, code, message):
        self.code = code
        self.message = message

def check_limits(user_id, message_text: str):
    if len(message_text) > MAX_MESSAGE_CHARS:
        raise LimitsExceeded('MESSAGE_TOO_LONG', f'Message exceeds {MAX_MESSAGE_CHARS} characters.')

    # Global daily budget
    today = datetime.date.today().isoformat()
    global_key = f'assistant_global_budget_{today}'
    global_count = cache.get(global_key, 0)
    if global_count >= GLOBAL_DAILY_BUDGET:
        raise LimitsExceeded('BUDGET_REACHED', 'System daily budget reached.')

    # User limits
    if user_id:
        hour = datetime.datetime.now().strftime('%Y-%m-%d-%H')
        user_hourly_key = f'assistant_user_hourly_{user_id}_{hour}'
        user_hourly_count = cache.get(user_hourly_key, 0)
        
        if user_hourly_count >= USER_LIMIT_PER_HOUR:
            raise LimitsExceeded('RATE_LIMITED', 'Hourly limit exceeded.')
            
        user_daily_key = f'assistant_user_daily_{user_id}_{today}'
        user_daily_count = cache.get(user_daily_key, 0)
        
        if user_daily_count >= USER_LIMIT_PER_DAY:
            raise LimitsExceeded('RATE_LIMITED', 'Daily limit exceeded.')

def record_usage(user_id):
    today = datetime.date.today().isoformat()
    global_key = f'assistant_global_budget_{today}'
    
    try:
        cache.incr(global_key)
    except ValueError:
        cache.set(global_key, 1, timeout=86400 * 2)
        
    if user_id:
        hour = datetime.datetime.now().strftime('%Y-%m-%d-%H')
        user_hourly_key = f'assistant_user_hourly_{user_id}_{hour}'
        user_daily_key = f'assistant_user_daily_{user_id}_{today}'
        
        try:
            cache.incr(user_hourly_key)
        except ValueError:
            cache.set(user_hourly_key, 1, timeout=3600 * 2)
            
        try:
            cache.incr(user_daily_key)
        except ValueError:
            cache.set(user_daily_key, 1, timeout=86400 * 2)

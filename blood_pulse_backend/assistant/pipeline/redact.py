# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

def convert_bangla_digits(text: str) -> str:
    if not text: return text
    bangla_to_english = str.maketrans('০১২৩৪৫৬৭৮৯', '0123456789')
    return text.translate(bangla_to_english)

def redact_text(text: str) -> str:
    """
    Redact BD phones, emails, and ID-like sequences.
    Convert Bangla digits before matching.
    """
    if not text:
        return text

    # Convert bangla digits to english for simpler matching
    text = convert_bangla_digits(text)
    
    # Phone numbers: +880 or 01 followed by 9 digits, allowing spaces or dashes anywhere between digits
    # A more flexible approach: find '01' followed by 9 digits interspersed with spaces/dashes.
    phone_pattern = re.compile(
        r'(?:\+88)?0[\s\-]*1[\s\-]*[3-9](?:[\s\-]*\d){8}'
    )
    
    # Emails
    email_pattern = re.compile(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+')
    
    redacted = email_pattern.sub('[REDACTED_EMAIL]', text)
    redacted = phone_pattern.sub('[REDACTED_PHONE]', redacted)
    
    # ID-like: 10, 13, 17 digits with optional spaces/dashes
    complex_id_pattern = re.compile(r'(?:\d[\s\-]*){10,17}')
    
    def replace_id_if_match(match):
        raw = match.group(0)
        digits_only = re.sub(r'[^\d]', '', raw)
        if len(digits_only) in (10, 13, 17):
            return '[REDACTED_ID]'
        return raw

    redacted = complex_id_pattern.sub(replace_id_if_match, redacted)
    
    return redacted

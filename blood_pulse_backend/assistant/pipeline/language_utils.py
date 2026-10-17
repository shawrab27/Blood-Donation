# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Language Detection & Routing Utilities for PulseAI.
Recognizes:
- Bengali Unicode script (বাংলা)
- Banglish (Bengali phonetic speech written in Latin alphabet, e.g. "kobe rokto dite parbo")
- English
Enforces the mandatory product rule:
- Bangla query -> Bangla script response
- Banglish query -> Bangla script response
- English query -> English response
"""

import re

# Comprehensive dictionary of distinctive Banglish tokens
BANGLISH_TOKENS = {
    'rokto', 'rokt', 'amake', 'amar', 'apnar', 'apnake', 'tumi', 'tomar',
    'dite', 'dibo', 'diba', 'debo', 'dilam', 'diyechi', 'diyesi',
    'parbo', 'parbi', 'parbe', 'parbo', 'kobe', 'koto', 'din', 'por',
    'lagbe', 'lagbo', 'kothay', 'kemon', 'keno', 'ki', 'bhalo', 'valo',
    'shathe', 'sathe', 'khabo', 'pani', 'khawa', 'khabar', 'vara', 'bhara',
    'jonno', 'thik', 'ase', 'ache', 'hobey', 'hobe', 'korbo', 'korechi',
    'korchi', 'korsilam', 'shomoy', 'somoy', 'rogir', 'dorkar', 'joggo',
    'jogota', 'bistarito', 'shob', 'kisu', 'kichu', 'vai', 'bhai', 'apu',
    'ojon', 'boyos', 'boyosh', 'matha', 'ghure', 'betha', 'batha',
    'shash', 'kosto', 'koshto', 'shustho', 'sustho', 'ashol', 'bujhi'
}

BANGLISH_PHRASE_PATTERNS = [
    r'\b(?:kobe|koto\s+din)\s+rokt[o]?\b',
    r'\brokt[o]?\s+(?:dite|dibo|diba|lagbe|dewar)\b',
    r'\b(?:amake|amar)\s+(?:ke\s+)?rokt[o]?\b',
    r'\b(?:ami\s+ki)\s+rokt[o]?\b',
    r'\b(?:ki|kobe)\s+khabo\b',
    r'\b(?:pani|jol)\s+koto\b',
    r'\b(?:cng|bus|auto|rickshaw)\s+(?:vara|bhara)\b',
    r'\b(?:vara|bhara)\s+koto\b',
    r'\b(?:theke|porjonto)\b',
]


def has_bangla_unicode(text: str) -> bool:
    """Returns True if string contains any Bengali Unicode characters."""
    return bool(re.search(r'[\u0980-\u09FF]', text or ''))


def is_banglish(text: str) -> bool:
    """
    Returns True if text is written in Latin characters but represents Bengali words.
    Checks token overlap against Banglish dictionary and phrase regexes.
    """
    if not text:
        return False
    # If it's already Bengali Unicode, it's not Banglish
    if has_bangla_unicode(text):
        return False

    norm = text.lower()

    # 1. Check distinctive phrases
    if any(re.search(pat, norm) for pat in BANGLISH_PHRASE_PATTERNS):
        return True

    # 2. Tokenize words and count Banglish matches
    words = re.findall(r'[a-z]+', norm)
    if not words:
        return False

    match_count = sum(1 for w in words if w in BANGLISH_TOKENS)
    # If at least 2 tokens match, or 1 match in a short query (<= 4 words)
    if match_count >= 2:
        return True
    if match_count >= 1 and len(words) <= 4:
        return True

    return False


def resolve_language_for_query(text: str, client_locale: str = None) -> tuple[str, bool]:
    """
    Resolves the query language and determines whether to respond in Bengali script.
    Returns:
      (language_code: 'bn' | 'en', is_bangla_script_response: bool)
    """
    if has_bangla_unicode(text):
        return ('bn', True)
    if is_banglish(text):
        # Banglish -> Respond in natural, polite Bengali script
        return ('bn', True)
    if client_locale == 'bn':
        return ('bn', True)
    return ('en', False)

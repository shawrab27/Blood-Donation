# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
from assistant.actions import ALLOWED_ACTIONS
from assistant.pipeline.redact import convert_bangla_digits

def check_numeric_claims(reply_text: str, kb_texts: list[str]) -> bool:
    """
    Returns True if safe, False if numeric claim guard is tripped.
    Looks for numbers followed by specific clinical/eligibility units.
    Rejects claims where numbers are absent from the retrieved sources.
    """
    if not reply_text:
        return True
    if not kb_texts:
        # If no knowledge base texts available, reject any clinical numeric claims
        units_pattern = r'\b(\d+(?:\.\d+)?)\s*(days?|months?|years?|weeks?|hours?|kg|g/dl|ml|দিন|দিনের|মাস|মাসের|বছর|বছরের|ঘণ্টা|ঘণ্টার|কেজি|কেজির|মিলি)\b'
        norm_reply = convert_bangla_digits(reply_text)
        return not bool(re.search(units_pattern, norm_reply, re.IGNORECASE))
        
    # Standardize both reply and KB texts to English digits for consistent matching
    reply_norm = convert_bangla_digits(reply_text)
    combined_kb = " ".join(kb_texts)
    kb_norm = convert_bangla_digits(combined_kb).lower()
    
    # Extract clinical numbers from the knowledge sources
    kb_numbers = set(re.findall(r'\b\d+(?:\.\d+)?\b', kb_norm))

    # Pattern for numbers tied to clinical / eligibility units
    units_pattern = r'\b(\d+(?:\.\d+)?)\s*(days?|months?|years?|weeks?|hours?|kg|g/dl|ml|দিন|দিনের|মাস|মাসের|বছর|বছরের|ঘণ্টা|ঘণ্টার|কেজি|কেজির|মিলি)\b'
    matches = list(re.finditer(units_pattern, reply_norm, re.IGNORECASE))
    
    for match in matches:
        num = match.group(1)
        full_match = match.group(0).lower()
        
        # Exact unit string in sources OR number present in source numbers
        if full_match in kb_norm:
            continue
        if num in kb_numbers:
            continue
            
        # The number is absent from all retrieved knowledge sources -> reject!
        return False
        
    return True

def strip_unallowed_urls(text: str) -> str:
    # Small allow-list
    allow_list = ["bloodpulse.app", "facebook.com/bloodpulse"]
    
    url_pattern = re.compile(r'(https?://[^\s]+)')
    def replacer(match):
        url = match.group(0)
        if any(allowed in url for allowed in allow_list):
            return url
        return "[LINK REMOVED]"
        
    return url_pattern.sub(replacer, text)

def apply_guards(result_json: dict, kb_entries) -> dict:
    # 1. Action IDs must be in allow-list
    actions = result_json.get("action_ids", [])
    valid_actions = [a for a in actions if a in ALLOWED_ACTIONS]
    result_json["action_ids"] = valid_actions
    
    # 2. Enforce Max Length
    reply = result_json.get("reply", "")
    if len(reply) > 800: # Safe upper bound for length
        reply = reply[:797] + "..."
        
    # 3. Numeric Claim Guard
    kb_ids_used = result_json.get("kb_ids_used", [])
    used_ids = {int(x) for x in kb_ids_used if str(x).isdigit()}
    
    used_kb_texts = []
    for entry in kb_entries:
        if not used_ids or entry.id in used_ids:
            used_kb_texts.extend([entry.title_en, entry.title_bn, entry.body_en, entry.body_bn])
            
    # Fallback to all retrieved entries if used_kb_texts is empty
    if not used_kb_texts and kb_entries:
        for entry in kb_entries:
            used_kb_texts.extend([entry.title_en, entry.title_bn, entry.body_en, entry.body_bn])
            
    if not check_numeric_claims(reply, used_kb_texts):
        lang = result_json.get("language", "en")
        if lang == "bn":
            result_json["reply"] = "আমি এ ব্যাপারে নিশ্চিত নই। সঠিক তথ্যের জন্য অনুগ্রহ করে একজন ডাক্তার বা আপনার নিকটস্থ ব্লাড ব্যাংকে যোগাযোগ করুন।"
        else:
            result_json["reply"] = "I'm not sure about that. Please ask a doctor or your nearest blood bank."
        result_json["flags"] = list(set(result_json.get("flags", []) + ["BLOCKED_NUMBER"]))
        
    # 4. Strip URLs
    result_json["reply"] = strip_unallowed_urls(result_json["reply"])
    
    return result_json


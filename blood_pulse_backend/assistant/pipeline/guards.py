# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
from assistant.actions import ALLOWED_ACTIONS

def check_numeric_claims(reply_text: str, kb_texts: list[str]) -> bool:
    """
    Returns True if safe, False if numeric claim guard is tripped.
    Looks for numbers followed by specific units.
    """
    # Units to check
    units_pattern = r'\b(\d+(?:\.\d+)?)\s*(days?|months?|years?|kg|g/dl|ml|দিন|মাস|বছর|কেজি|মিলি)\b'
    matches = re.finditer(units_pattern, reply_text, re.IGNORECASE)
    
    combined_kb = " ".join(kb_texts).lower()
    
    for match in matches:
        full_match = match.group(0).lower()
        if full_match not in combined_kb:
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
    used_kb_texts = []
    for entry in kb_entries:
        if entry.id in kb_ids_used:
            used_kb_texts.extend([entry.body_en, entry.body_bn])
            
    if not check_numeric_claims(reply, used_kb_texts):
        result_json["reply"] = "I'm not sure about that. Please ask a doctor or your nearest blood bank."
        result_json["flags"] = result_json.get("flags", []) + ["BLOCKED_NUMBER"]
        
    # 4. Strip URLs
    result_json["reply"] = strip_unallowed_urls(result_json["reply"])
    
    return result_json

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

def load_emergency_phrases():
    # In a real scenario, this might load from a file or DB.
    # We'll hardcode the starter set here for reliability as requested.
    return [
        "urgent blood need", "জরুরি রক্ত", "urgent rokt", 
        "accident", "দুর্ঘটনা", "durghotona",
        "icu", "আইসিইউ",
        "bleeding", "রক্তপাত", "roktopat",
        "unconscious", "অজ্ঞান", "oggan",
        "fainting", "severe reaction",
        "chest pain", "বুক ব্যথা", "buk betha"
    ]

def detect_emergency(text: str) -> dict:
    if not text:
        return None
        
    phrases = load_emergency_phrases()
    text_lower = text.lower()
    
    for phrase in phrases:
        if phrase in text_lower:
            return {
                "emergency": True,
                "reply": "If someone is in danger, call 999 now or go to the nearest hospital.",
                "language": "en", # Fallback language, could be dynamically set
                "action_ids": ["call_999", "open_emergency_form"],
                "out_of_scope": False,
                "needs_human": False,
                "kb_ids_used": []
            }
            
    return None

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re

def load_emergency_phrases():
    """Emergency trigger keywords and phrases (English and Bengali)."""
    return [
        # Explicit mandatory triggers
        "dying", "faint", "fainting", "die", "collapse", "collapsed",
        # Urgent blood needs
        "urgent blood need", "জরুরি রক্ত", "urgent rokt", "জরুরী রক্ত",
        # Trauma & Medical emergencies
        "accident", "দুর্ঘটনা", "durghotona",
        "icu", "আইসিইউ",
        "bleeding", "রক্তপাত", "roktopat",
        "unconscious", "অজ্ঞান", "oggan", "জ্ঞান হারিয়ে", "জ্ঞান হারাচ্ছে",
        "মরে যাচ্ছি", "মারা যাচ্ছে", "মুমূর্ষু",
        "severe reaction", "heart attack", "stroke",
        "chest pain", "বুক ব্যথা", "buk betha",
        "convulsion", "seizure", "খিঁচুনি"
    ]

def detect_emergency(text: str) -> dict:
    if not text:
        return None
        
    phrases = load_emergency_phrases()
    text_lower = text.lower()
    
    is_emergency = False
    for phrase in phrases:
        # Check boundary for short words like 'die', 'faint'
        if phrase in ("die", "faint", "icu"):
            if re.search(rf'\b{re.escape(phrase)}\b', text_lower):
                is_emergency = True
                break
        else:
            if phrase in text_lower:
                is_emergency = True
                break
                
    if is_emergency:
        is_bn = bool(re.search(r'[\u0980-\u09FF]', text))
        reply = (
            "জরুরি পরিস্থিতিতে অবিলম্বে ৯৯৯ নম্বরে কল করুন অথবা নিকটস্থ হাসপাতালে যোগাযোগ করুন।"
            if is_bn
            else "If someone is in danger, call 999 now or go to the nearest hospital."
        )
        return {
            "emergency": True,
            "reply": reply,
            "language": "bn" if is_bn else "en",
            "action_ids": ["call_999", "open_emergency_form"],
            "out_of_scope": False,
            "needs_human": False,
            "kb_ids_used": []
        }
            
    return None


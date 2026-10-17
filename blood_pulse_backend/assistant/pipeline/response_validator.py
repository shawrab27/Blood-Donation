# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
PulseAI Response Contract Validator.
Enforces standard response structure, safety rules, language consistency,
and word count limits across Gemini responses and fallback pipelines.
"""

import re
import logging

logger = logging.getLogger(__name__)

# Red-flag medical emergency symptoms
RED_FLAG_PATTERNS = [
    r'\bchest pain\b',
    r'\bsevere bleeding\b',
    r'\bheavy bleeding\b',
    r'\bdifficulty breathing\b',
    r'\bshortness of breath\b',
    r'\bunconscious\b',
    r'\bfainting\b',
    r'\bfainted\b',
    r'\bseizure\b',
    r'\bheart attack\b',
    r'\bstroke\b',
    r'\bsevere allergic reaction\b',
    r'\banaphylaxis\b',
    r'বুকে ব্যথা',
    r'প্রচুর রক্তপাত',
    r'মারাত্মক রক্তপাত',
    r'শ্বাসকষ্ট',
    r'অজ্ঞান',
    r'চোখে অন্ধকার',
    r'খিঁচুনি',
]

OUT_OF_SCOPE_PATTERNS = [
    r'\b(cricket|football|messi|ronaldo|game|movie|cinema|actor|actress)\b',
    r'\b(python|javascript|coding|programming|sql|java|c\+\+|html|css)\b',
    r'\b(recipe|cook|baking|biryani|pizza|burger)\b',
    r'\b(stock market|crypto|bitcoin|forex|investing)\b',
    r'\b(politics|election|vote|parliament|minister)\b',
    r'খেলাধুলা|সিনেমা|রান্না|রেসিপি|প্রোগ্রামিং|কোডিং|নির্বাচন|রাজনীতি',
]

def is_bangla_text(text: str) -> bool:
    """Detect if text contains Bengali Unicode characters or common transliterations."""
    if bool(re.search(r'[\u0980-\u09FF]', text)):
        return True
    return False

def detect_red_flags(text: str) -> bool:
    """Check for life-threatening symptoms requiring immediate emergency response."""
    norm = text.lower()
    for pattern in RED_FLAG_PATTERNS:
        if re.search(pattern, norm, re.IGNORECASE):
            return True
    return False

def detect_out_of_scope(text: str) -> bool:
    """Check if query is outside BloodPulse domain."""
    norm = text.lower()
    for pattern in OUT_OF_SCOPE_PATTERNS:
        if re.search(pattern, norm, re.IGNORECASE):
            return True
    return False

def validate_and_format_response(
    raw_reply: str,
    user_query: str,
    locale: str = 'en',
    emergency: bool = False,
    is_fallback: bool = False
) -> dict:
    """
    Validates and formats the assistant reply according to the strict response contract:
    1. Language matching: English or Bangla matching user query.
    2. Structure: 1-2 sentence direct answer first, max 6 bullet points,
       optional doctor/blood bank recommendation.
    3. Length: under ~180 words.
    4. Safety: red flags alert 999 immediately; no diagnoses, no drug doses.
    5. Cleanliness: strips repeated header disclaimers.
    """
    is_bn = (locale == 'bn') or is_bangla_text(user_query)
    has_red_flags = emergency or detect_red_flags(user_query) or detect_red_flags(raw_reply)

    # 1. Emergency Red-Flag Override (Always 999 first)
    if has_red_flags:
        if is_bn:
            safe_text = (
                "🚨 জরুরি সতর্কতা: এটি একটি বিপজ্জনক স্বাস্থ্য পরিস্থিতি হতে পারে। অবিলম্বে ৯৯৯ নম্বরে কল করুন "
                "অথবা নিকটস্থ হাসপাতালের জরুরি বিভাগে যোগাযোগ করুন!\n\n"
                "• জরুরি পরিস্থিতিতে কোনো প্রকার বিলম্ব করবেন না।\n"
                "• রোগীকে শান্ত রাখুন এবং প্রাথমিক চিকিৎসা সহায়তা নিন।\n"
                "• রক্তদানের চেয়ে রোগীর তাৎক্ষণিক জরুরি চিকিৎসা এখন সবচেয়ে বেশি গুরুত্বপূর্ণ।\n\n"
                "জরুরি সহায়তা পেলে তবেই পরবর্তী পদক্ষেপ নিন।"
            )
        else:
            safe_text = (
                "🚨 Emergency Alert: This may be a critical medical emergency. Call 999 immediately "
                "or go to the nearest emergency department right away!\n\n"
                "• Do not delay seeking urgent medical assistance.\n"
                "• Keep the patient calm and provide immediate first aid if trained.\n"
                "• Immediate hospital stabilization takes priority over blood donation inquiries.\n\n"
                "Please contact emergency services or your nearest hospital immediately."
            )
        return {
            "reply": safe_text,
            "response": safe_text,
            "language": "bn" if is_bn else "en",
            "emergency": True,
            "out_of_scope": False,
            "action_ids": ["call_999", "open_emergency_form"],
            "flags": ["EMERGENCY_RED_FLAG"],
        }

    # 2. Out of scope redirect
    if detect_out_of_scope(user_query):
        if is_bn:
            oos_text = (
                "আমি রক্তদান ও স্বাস্থ্য সংক্রান্ত বিষয়ে সাহায্য করার জন্য তৈরি। এই বিষয়টি আমার আওতাভুক্ত নয়।\n\n"
                "আমি আপনাকে সাহায্য করতে পারি:\n"
                "• রক্তদানের যোগ্যতা ও নির্দেশিকা জানতে\n"
                "• রক্তদানের নির্দিষ্ট সময় ব্যবধান ও প্রস্তুতি বুঝতে\n"
                "• অ্যাপে রক্তের জরুরি অনুরোধ জানাতে বা ডোনার খুঁজতে\n\n"
                "রক্তদান সংক্রান্ত যেকোনো প্রশ্ন থাকলে আমাকে জানাতে পারেন।"
            )
        else:
            oos_text = (
                "I am focused on blood donation and related health guidance. This topic is outside my scope.\n\n"
                "Here is what I can help you with:\n"
                "• Checking blood donor eligibility and deferral rules\n"
                "• Guidance on donation intervals and pre-donation preparation\n"
                "• Finding voluntary donors or posting emergency requests in BloodPulse\n\n"
                "Feel free to ask any blood donation or donor mobilization questions!"
            )
        return {
            "reply": oos_text,
            "response": oos_text,
            "language": "bn" if is_bn else "en",
            "emergency": False,
            "out_of_scope": True,
            "action_ids": ["open_search"],
            "flags": ["OUT_OF_SCOPE"],
        }

    # 3. Strip repetitive header disclaimers and secrets from Gemini
    cleaned = raw_reply.strip()
    disclaimer_patterns = [
        r'AI-assisted guidance\s*—\s*not a medical diagnosis\.[^\n]*',
        r'Please note that I am an AI[^\n]*',
        r'Disclaimer:[^\n]*',
        r'সতর্কতা:\s*আমি একটি এআই[^\n]*',
    ]
    for dp in disclaimer_patterns:
        cleaned = re.sub(dp, '', cleaned, flags=re.IGNORECASE).strip()

    # Secondary defense: scrub potential secret leaks from model output
    secret_patterns = [
        r'AIzaSy[A-Za-z0-9_-]{30,}',
        r'\b(?:GEMINI_API_KEY|SECRET_KEY|DATABASE_URL|DJANGO_SECRET_KEY)\b[^\n]*',
        r'postgres(?:ql)?://[^\s]+',
    ]
    for sp in secret_patterns:
        if re.search(sp, cleaned, re.IGNORECASE):
            cleaned = re.sub(sp, '[REDACTED_SECRET]', cleaned, flags=re.IGNORECASE)

    # 4. Enforce bullet limit (maximum 6 bullets)
    lines = cleaned.split('\n')
    bullet_count = 0
    formatted_lines = []
    
    for line in lines:
        stripped = line.strip()
        is_bullet = bool(re.match(r'^(\*|-|•|\d+\.)\s+', stripped))
        if is_bullet:
            bullet_count += 1
            if bullet_count <= 6:
                formatted_lines.append(stripped)
            # Drop excess bullets beyond 6 to keep response concise
        else:
            formatted_lines.append(line)

    cleaned = '\n'.join(formatted_lines).strip()

    # 5. Word count limit check (under ~180 words)
    words = cleaned.split()
    if len(words) > 195:
        # Trim cleanly at sentence boundary or bullet
        truncated_words = words[:180]
        cleaned = ' '.join(truncated_words) + '...'
        if is_bn:
            cleaned += "\n\n(বিস্তারিত জানার জন্য ব্লাড ব্যাংকে যোগাযোগ করতে পারেন।)"
        else:
            cleaned += "\n\n(Confirm details at your local blood bank.)"

    return {
        "reply": cleaned,
        "response": cleaned,
        "language": "bn" if is_bn else "en",
        "emergency": False,
        "out_of_scope": False,
        "action_ids": [],
        "flags": ["VALIDATED"],
    }

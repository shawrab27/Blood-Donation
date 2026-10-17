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
        units_pattern = r'(\d+(?:\.\d+)?)\s*(days?|months?|years?|weeks?|hours?|kg|g/dl|ml|দিন|দিনের|মাস|মাসের|বছর|বছরের|ঘণ্টা|ঘণ্টার|ঘন্টা|ঘন্টার|কেজি|কেজির|মিলি)'
        norm_reply = convert_bangla_digits(reply_text)
        return not bool(re.search(units_pattern, norm_reply, re.IGNORECASE))
        
    # Standardize both reply and KB texts to English digits for consistent matching
    reply_norm = convert_bangla_digits(reply_text)
    combined_kb = " ".join(kb_texts)
    kb_norm = convert_bangla_digits(combined_kb).lower()
    
    # Extract clinical numbers from the knowledge sources
    kb_numbers = set(re.findall(r'\b\d+(?:\.\d+)?\b', kb_norm))

    # Pattern for numbers tied to clinical / eligibility units
    units_pattern = r'(\d+(?:\.\d+)?)\s*(days?|months?|years?|weeks?|hours?|kg|g/dl|ml|দিন|দিনের|মাস|মাসের|বছর|বছরের|ঘণ্টা|ঘণ্টার|ঘন্টা|ঘন্টার|কেজি|কেজির|মিলি)'
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


# ==============================================================================
# Prompt Injection, Jailbreak, and Medical Misuse Defense (Anomaly #34)
# ==============================================================================

JAILBREAK_PATTERNS = [
    # Instruction override / ignore instructions
    r'\b(?:ignore|disregard|forget|override|bypass|clear|reset)\s+(?:all\s+)?(?:previous|prior|above|system)?\s*(?:instructions?|prompts?|rules?|directives?|guidelines?)\b',
    r'\b(?:dan|jailbreak|jailbroken|unrestricted|godmode|evil\s*twin|anti-gpt|do\s*anything\s*now)\b',
    r'\b(?:developer|admin|debug|super-?user|root)\s*(?:mode|prompt|privileges?|override)\b',
    r'\b(?:roleplay|pretend|act)\s*(?:as)?\s*(?:an?)?\s*(?:hacker|unrestricted|evil|jailbroken|anti-rules|bypass|ruleless)\b',
    r'\b(?:you\s+are\s+now|imagine\s+you\s+are)\s+(?:an?\s+)?(?:hacker|unrestricted|evil|jailbroken)\b',
    r'\boverride\s+(?:this\s+)?system\b',
    r'###\s*.*?(?:SYSTEM|OVERRIDE|ADMIN).*?###',
    r'\[(?:SYSTEM|DEVELOPER|ROOT)\]',
    # Bangla jailbreaks
    r'(?:পূর্বের|আগের|সব|সকল)\s*(?:নির্দেশ|নির্দেশনা|নিয়ম|নিয়ম|রুলস|প্রম্পট)?\s*(?:ভুলে\s*যাও|বাদ\s*দাও|মুছে\s*ফেলো|উপেক্ষা\s*করো)',
    r'(?:জেলব্রেক|সিস্টেম\s*ওভাররাইড|ডেভেলপার\s*মোড|অ্যাডমিন\s*মোড)',
    r'(?:ভণ্ডামী\s*করো|তুমি\s*এখন\s*হ্যাকার|তুমি\s*এখন\s*সীমাহীন|নিয়ম\s*না\s*মেনে\s*উত্তর\s*দাও)',
    # Banglish jailbreaks
    r'\bage\s*ki\s*bolsi\s*(?:shob|sob)?\s*(?:bhule|vule)\s*jao\b',
    r'\b(?:shob|sob)\s*(?:instruction|rules?|niyom)?\s*(?:bhule|vule|bad)\s*(?:jao|dao)\b',
    r'\b(?:jailbreak|developer\s*mode|system\s*override|unrestricted)\s*(?:koro|chalu\s*koro)\b',
    r'\b(?:pretend\s*koro|tumi\s*ekhon\s*(?:hacker|unrestricted|bad\s*ai))\b',
    r'\b(?:sob|shob)\s*rule\s*(?:baad|bad|bhule\s*jao|vule\s*jao)\b',
]

EXFILTRATION_PATTERNS = [
    # System prompt leak
    r'\b(?:reveal|show|print|display|tell\s+me|output|dump|leak)\s+(?:your\s+)?(?:system\s*prompt|initial\s*instructions?|prompt\s*template|developer\s*message|developer\s*prompt)\b',
    r'\b(?:what\s+is\s+your\s+system\s*prompt|what\s+are\s+your\s+instructions|show\s+prompt\s+above|repeat\s+the\s+words\s+above)\b',
    r'\b(?:api[_\s-]*key|secret[_\s-]*key|gemini[_\s-]*api[_\s-]*key|database[_\s-]*url|neon[_\s-]*db|db[_\s-]*password)\b',
    r'\b(?:show|get|dump|list)\s+(?:all\s+)?(?:donor|user|requester)\s+(?:phones?|passwords?|emails?|contacts?|nid)\b',
    r'\b(?:donors?|users?|requesters?)(?:\'s)?\s*(?:and\s+their\s+)?(?:phones?|passwords?|emails?|contacts?|nid|phone\s*numbers?)\b',
    # Bangla exfiltration
    r'(?:সিস্টেম\s*প্রম্পট|গোপন\s*কোড|এপিআই\s*কী|ডাটাবেজ\s*পাসওয়ার্ড|সিক্রেট\s*কী|সিস্টেম\s*নির্দেশ)',
    r'(?:সব|সকল|সকলের)?\s*(?:ডোনারের|ইউজারদের|ব্যবহারকারীদের)\s*(?:ফোন|পাসওয়ার্ড|ইমেইল|এনআইডি|ঠিকানা|তথ্য)',
    r'(?:এনআইডি|পাসওয়ার্ড|গোপন\s*কোড)\s*(?:নম্বর)?\s*(?:দাও|দেখাও|বলো|বের\s*করো)',

    # Banglish exfiltration
    r'\b(?:system\s*prompt|secret\s*key|api\s*key|database\s*password)\s*(?:ki|bolo|dao|dekhao)\b',
    r'\b(?:shob|sob)?\s*(?:user|donor)(?:\s*(?:er|der))?\s*(?:phone|contact|number)?\s*(?:number|password)\s*(?:dao|dekhao|bolo)\b',
    r'\b(?:tumar\s+)?(?:api\s*key|secret\s*key|database\s*password)\s*(?:bolo|dao|dekhao)\b',
    r'\b(?:donor|user)(?:\s*(?:er|der))?\s*(?:password|contact|phone)\s*(?:bolo|dao|dekhao)\b',
]

MEDICATION_PATTERNS = [
    # Prescription / dosage misuse
    r'\b(?:how\s+many\s+mg|what\s+dosage|prescribe\s+me|prescribe\s+medicine|how\s+many\s+tablets|overdose\s+of|lethal\s+dose|how\s+much\s+paracetamol\s+to\s+take)\b',
    r'\b(?:dosing\s+instructions?|take\s+\d+\s*mg|child\s+dose\s+for|how\s+much\s+(?:mg|ml|tablets?)\s+should\s+i\s+take)\b',
    r'\b(?:prescribe\s+me\s+strong\s+antibiotics)\b',
    # Bangla medication misuse
    r'(?:কত\s*মিলিগ্রাম|কত\s*এমজি|ডোজ\s*কত|কী\s*ওষুধ\s*খাব|প্রেসক্রিপশন\s*দাও|ওষুধের\s*মাত্রা|প্যারাসিটামল\s*কতটুকু\s*খাব|কতটুকু\s*খাব)',
    # Banglish medication misuse
    r'\b(?:kototuku|koto\s*mg|dosage\s*koto|ki\s*osudh\s*khabo|prescription\s*dao|paracetamol\s*koto\s*mg|overdose\s*koto)\b',
    r'\b(?:kototuku\s+medicine\s+khabo)\b',
]

ENCODING_INJECTION_PATTERNS = [
    r'\b(?:base64|rot13|hex|ascii\s*code|cdata)\s*:\s*[A-Za-z0-9+/=]{10,}\b',
    r'(?:union\s+select|drop\s+table|1=1--|<script>|javascript:|eval\(|exec\()',
]


def detect_prompt_injection(user_text: str, locale: str = 'bn') -> dict | None:
    """
    Evaluates input text against known jailbreak, prompt injection, data exfiltration,
    medication dosing, and injection attack vectors.
    Returns a safe refusal dict if blocked, or None if input is safe.
    """
    if not user_text:
        return None

    from assistant.pipeline.language_utils import resolve_language_for_query
    lang_res = resolve_language_for_query(user_text, locale)
    is_bn = (lang_res[0] == 'bn') if isinstance(lang_res, (list, tuple)) else (lang_res == 'bn')
    norm_text = user_text.lower().strip()


    # 1. Medication dosing misuse
    for pat in MEDICATION_PATTERNS:
        if re.search(pat, norm_text, re.IGNORECASE):
            msg = (
                "আমি কোনো ওষুধের প্রেসক্রিপশন বা সেবনের নির্দিষ্ট মাত্রা (ডোজ) নির্ধারণ করতে পারি না। "
                "ওষুধের সঠিক মাত্রা ও নির্দেশনার জন্য অনুগ্রহ করে একজন রেজিস্টার্ড চিকিৎসকের পরামর্শ নিন।"
                if is_bn else
                "I cannot prescribe medications or determine drug dosages. "
                "Please consult a qualified physician or registered pharmacist for proper medical prescriptions and dosing instructions."
            )
            return {
                "reply": msg,
                "response": msg,
                "source": "medication_guard",
                "confidence": 1.0,
                "language": "bn" if is_bn else "en",
                "emergency": False,
                "out_of_scope": True,
                "action_ids": ["open_search"],
                "flags": ["MEDICATION_DOSING_REFUSED", "OUT_OF_SCOPE"],
            }

    # 2. System prompt and secrets exfiltration
    for pat in EXFILTRATION_PATTERNS:
        if re.search(pat, norm_text, re.IGNORECASE):
            msg = (
                "আমি কোনো অভ্যন্তরীণ সিস্টেম প্রম্পট, গোপন কোড, বা অন্যান্য ব্যবহারকারীর ব্যক্তিগত তথ্য প্রকাশ করতে পারি না। "
                "ব্লাডপালস-এর রক্তদান সংক্রান্ত যেকোনো তথ্যে আপনাকে সাহায্য করতে পারলে আমি আনন্দিত হব।"
                if is_bn else
                "I cannot reveal internal system instructions, credentials, or private user data. "
                "I am here to assist you with blood donation and donor mobilization on BloodPulse."
            )
            return {
                "reply": msg,
                "response": msg,
                "source": "exfiltration_guard",
                "confidence": 1.0,
                "language": "bn" if is_bn else "en",
                "emergency": False,
                "out_of_scope": True,
                "action_ids": ["open_search"],
                "flags": ["DATA_EXFILTRATION_BLOCKED", "JAILBREAK_ATTEMPT_BLOCKED"],
            }

    # 3. Jailbreak & Instruction Override
    for pat in JAILBREAK_PATTERNS:
        if re.search(pat, norm_text, re.IGNORECASE):
            msg = (
                "আমি এই অনুরোধটি পূরণ করতে পারছি না। আমি ব্লাডপালস-এর রক্তদান ও প্রাথমিক স্বাস্থ্য নির্দেশিকা সহকারী PulseAI। "
                "আমি নিরাপত্তা নীতি বা সিস্টেম নির্দেশনা উপেক্ষা করতে পারি না। রক্তদান সংক্রান্ত যেকোনো তথ্যের জন্য আমাকে জিজ্ঞাসা করতে পারেন।"
                if is_bn else
                "I cannot fulfill this request. I am PulseAI, a dedicated assistant for blood donation on BloodPulse. "
                "I cannot bypass safety protocols or disregard system instructions. Feel free to ask any blood donation questions!"
            )
            return {
                "reply": msg,
                "response": msg,
                "source": "jailbreak_guard",
                "confidence": 1.0,
                "language": "bn" if is_bn else "en",
                "emergency": False,
                "out_of_scope": True,
                "action_ids": ["open_search"],
                "flags": ["JAILBREAK_ATTEMPT_BLOCKED"],
            }

    # 4. Encoding / Code Injection
    for pat in ENCODING_INJECTION_PATTERNS:
        if re.search(pat, norm_text, re.IGNORECASE):
            msg = (
                "অনুরোধটিতে অনিরাপদ সংকেত বা কোড সনাক্ত করা হয়েছে। দয়া করে সাধারণ ভাষায় আপনার রক্তদান সংক্রান্ত প্রশ্ন লিখুন।"
                if is_bn else
                "Unsafe code or encoding pattern detected. Please enter your blood donation inquiry in standard plain text."
            )
            return {
                "reply": msg,
                "response": msg,
                "source": "injection_guard",
                "confidence": 1.0,
                "language": "bn" if is_bn else "en",
                "emergency": False,
                "out_of_scope": True,
                "action_ids": ["open_search"],
                "flags": ["JAILBREAK_ATTEMPT_BLOCKED", "CODE_INJECTION_BLOCKED"],
            }

    return None


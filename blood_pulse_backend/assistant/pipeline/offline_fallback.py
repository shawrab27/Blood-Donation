# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
from api.conf import DONOR_COOLDOWN_DAYS
from assistant.pipeline.language_utils import resolve_language_for_query

def detect_urgent_symptoms(text: str) -> bool:
    norm = text.lower()
    urgent_patterns = [
        r'\bchest\s+pain\b', r'\bsevere\s+bleeding\b', r'\bunconscious\b',
        r'\bpassed\s+out\b', r'\bfainted\b', r'\bfainting\b', r'\bbreathing\s+difficulty\b',
        r'\bshortness\s+of\s+breath\b', r'\bheart\s+attack\b', r'\bstroke\b',
        r'বুকে\s*ব্যথা', r'প্রচুর\s*রক্তপাত', r'শ্বাসকষ্ট', r'অজ্ঞান', r'মাথা\s*ঘুরে\s*পড়ে',
        r'দম\s*বন্ধ', r'হৃদরোগ', r'তীব্র\s*যন্ত্রণা',
        # Banglish emergency terms
        r'\bbuke[y]?\s+b[e|a]tha\b', r'\brokto\s+porche\b', r'\bshas[h]?\s+k[o]?s[h]?to\b',
        r'\boggan\b', r'\bbeosh\b', r'\bmatha\s+ghur[e|che]\b'
    ]
    return any(re.search(pat, norm) for pat in urgent_patterns)

def get_offline_guidance(query: str, locale: str = 'bn') -> dict:
    """
    Deterministic clinical fallback for core intents from reviewed knowledge.
    Returns:
      {
        'reply': str (labeled '[Offline guidance]'),
        'emergency': bool,
        'actions': list[str],
        'matched_intent': str
      }
    """
    resolved_lang, is_bn = resolve_language_for_query(query, client_locale=locale)
    norm = query.lower()

    # 1. Safety Guard: Urgent Symptoms -> Dial 999 / Doctor immediately (No diagnosis)
    if detect_urgent_symptoms(norm):
        if is_bn:
            reply = (
                "[অফলাইন নির্দেশনা] ব্লাডপালস চিকিৎসা সংক্রান্ত রোগনির্ণয় প্রদান করে না। "
                "তীব্র বা বিপজ্জনক উপসর্গ দেখা দিলে অবিলম্বে ৯৯৯ নম্বরে কল করুন অথবা নিকটস্থ জরুরি বিভাগে যোগাযোগ করুন।"
            )
        else:
            reply = (
                "[Offline guidance] BloodPulse does not provide clinical diagnosis. "
                "For severe, sudden, or life-threatening symptoms, dial 999 or proceed to the nearest emergency room immediately."
            )
        return {
            'reply': reply,
            'emergency': True,
            'action_ids': ['call_999', 'open_emergency_form'],
            'matched_intent': 'urgent_symptoms'
        }

    # 2. Donation Interval / Cooldown
    interval_kws = [
        'interval', 'how long', 'cooldown', 'how many days', 'how often', 'next donation',
        'kobe rokt', 'kobe rokto', 'koto din por', 'koto din por por', 'koto din baki',
        'kobe abar', 'কত দিন পর', 'কবে রক্ত', 'বিরতি', 'পরবর্তী রক্তদান', 'কতদিন পর'
    ]
    if any(kw in norm for kw in interval_kws):
        days = DONOR_COOLDOWN_DAYS  # strictly 90 days from api.conf
        weeks = days // 7
        if is_bn:
            reply = (
                f"[অফলাইন নির্দেশনা] সম্পূর্ণ রক্তদানের (Whole Blood) ক্ষেত্রে ন্যূনতম বিরতি কঠোরভাবে {days} দিন "
                f"({weeks} সপ্তাহ)। এটি আপনার শরীরকে লোহিত রক্তকণিকা ও আয়রনের ঘাটতি পূরণ করার পর্যাপ্ত সময় দেয়।"
            )
        else:
            reply = (
                f"[Offline guidance] The mandatory interval between whole blood donations is strictly {days} days "
                f"({weeks} weeks). This ensures sufficient time for your body to replenish red blood cells and iron stores."
            )
        return {
            'reply': reply,
            'emergency': False,
            'action_ids': ['open_profile'],
            'matched_intent': 'donation_interval'
        }

    # 3. What to eat before donating (Nutrition)
    food_kws = [
        'eat', 'food', 'meal', 'nutrition', 'khabar', 'ki khabo', 'khawa', 'khawa dawa',
        'diet', 'age ki khabo', 'khali pete', 'কী খাব', 'খাবার', 'খাওয়া', 'ডায়েট', 'আগে কি খাব', 'না খেয়ে'
    ]
    if any(kw in norm for kw in food_kws):
        if is_bn:
            reply = (
                "[অফলাইন নির্দেশনা] রক্তদানের ২ থেকে ৩ ঘণ্টা পূর্বে হালকা ও পুষ্টিকর খাবার গ্রহণ করুন। "
                "চর্বিযুক্ত বা অতিরিক্ত ভাজাপোড়া খাবার পরিহার করুন, কারণ এটি রক্ত পরীক্ষার ফলাফলে প্রভাব ফেলতে পারে। "
                "খালি পেটে কখনোই রক্তদান করবেন না।"
            )
        else:
            reply = (
                "[Offline guidance] Have a light, nutritious meal 2 to 3 hours before giving blood. "
                "Avoid greasy or fatty foods as they can interfere with blood testing. Never donate on an empty stomach."
            )
        return {
            'reply': reply,
            'emergency': False,
            'action_ids': [],
            'matched_intent': 'pre_donation_nutrition'
        }

    # 4. Hydration / Fluids
    hydration_kws = [
        'water', 'drink', 'fluid', 'hydrate', 'hydration', 'pani', 'pani koto khabo',
        'koto pani', 'jol', 'পানি', 'জল', 'পানীয়', 'তরল'
    ]
    if any(kw in norm for kw in hydration_kws):
        if is_bn:
            reply = (
                "[অফলাইন নির্দেশনা] রক্তদানের আগে ও পরে পর্যাপ্ত পানি পান করা অত্যন্ত জরুরি। "
                "রক্তদানের কিছুক্ষণ পূর্বে অন্তত ৫০০ মিলি পানি পান করুন। রক্তদানের আগে অতিরিক্ত ক্যাফেইন বা অ্যালকোহল পরিহার করুন।"
            )
        else:
            reply = (
                "[Offline guidance] Proper hydration is essential. Drink at least 500 ml (2 glasses) of water shortly "
                "before donating, and drink plenty of fluids afterwards. Avoid excessive caffeine and alcohol."
            )
        return {
            'reply': reply,
            'emergency': False,
            'action_ids': [],
            'matched_intent': 'hydration'
        }

    # 5. Aftercare / Recovery
    aftercare_kws = [
        'aftercare', 'after donating', 'after donation', 'post donation', 'dizziness',
        'pore ki', 'pore ki korbo', 'rokto dewar pore', 'rokto dewar por', 'matha ghurle',
        'রক্তদানের পর', 'পরে করণীয়', 'বিশ্রাম', 'মাথা ঘোরা', 'রিকভারি', 'পরবর্তী যত্ন'
    ]
    if any(kw in norm for kw in aftercare_kws):
        if is_bn:
            reply = (
                "[অফলাইন নির্দেশনা] রক্তদানের পর ১০–১৫ মিনিট বিশ্রাম নিন এবং জুস বা পানি পান করুন। "
                "পরবর্তী ২৪ ঘণ্টা ভারী ওজন তোলা বা কঠোর শারীরিক পরিশ্রম থেকে বিরত থাকুন। ইনজেকশনের জায়গায় ব্যান্ডেজ কয়েক ঘণ্টা লাগিয়ে রাখুন।"
            )
        else:
            reply = (
                "[Offline guidance] Rest at the donation center for 10–15 minutes and enjoy juice or water. "
                "Avoid strenuous physical exercise and heavy lifting for the next 24 hours. Keep the bandage on for several hours."
            )
        return {
            'reply': reply,
            'emergency': False,
            'action_ids': [],
            'matched_intent': 'aftercare'
        }

    # 6. General Eligibility
    eligibility_kws = [
        'eligible', 'eligibility', 'can i donate', 'criteria', 'rule', 'weight', 'age', 'hemoglobin',
        'joggo', 'jogota', 'shortho', 'sorto', 'ojon', 'boyos', 'boyosh',
        'ami ki rokto dite parbo', 'ke rokto dite parbe', 'যোগ্য', 'যোগ্যতা', 'রক্ত দিতে পারব',
        'শর্ত', 'ওজন', 'বয়স', 'হিমোগ্লোবিন'
    ]
    if any(kw in norm for kw in eligibility_kws):
        days = DONOR_COOLDOWN_DAYS
        if is_bn:
            reply = (
                "[অফলাইন নির্দেশনা] রক্তদানের সাধারণ যোগ্যতা ও শর্তাবলী:\n\n"
                "• বয়স: ১৮ থেকে ৬০ বছরের মধ্যে।\n"
                "• শারীরিক ওজন: কমপক্ষে ৫০ কেজি (১১০ পাউন্ড)।\n"
                "• সাধারণ স্বাস্থ্য: সুস্থ ও নীরোগ (বিগত ১৪ দিনে জ্বর বা সংক্রামক রোগ নেই)।\n"
                "• হিমোগ্লোবিনের মাত্রা: স্বাভাবিক (কমপক্ষে ১২.৫ গ্রাম/ডিএল)।\n"
                f"• বিরতি: পূর্ববর্তী রক্তদান থেকে কমপক্ষে {days} দিন অতিবাহিত হতে হবে।"
            )
        else:
            reply = (
                "[Offline guidance] General blood donation eligibility requirements:\n\n"
                "• Age: 18 to 60 years old.\n"
                "• Weight: At least 50 kg (110 lbs).\n"
                "• General health: Feel fit and healthy (no flu or infections within 14 days).\n"
                "• Hemoglobin: At least 12.5 g/dL.\n"
                f"• Interval: At least {days} days since your last whole blood donation."
            )
        return {
            'reply': reply,
            'emergency': False,
            'action_ids': ['open_search'],
            'matched_intent': 'eligibility'
        }

    # 7. Default general guidance
    days = DONOR_COOLDOWN_DAYS
    if is_bn:
        reply = (
            "[অফলাইন নির্দেশনা] ব্লাডপালস নিরাপদ রক্তদান ও জরুরি ডোনার সংযোগে সহায়ক। "
            f"রক্তদানের প্রধান শর্ত: বয়স ১৮-৬০ বছর, ওজন কমপক্ষে ৫০ কেজি, এবং পূর্ববর্তী রক্তদানের পর ন্যূনতম {days} দিন বিরতি। "
            "জরুরি রক্তের প্রয়োজনে ব্লাড হাব থেকে রিকুয়েস্ট পোস্ট করুন অথবা ৯৯৯ নম্বরে যোগাযোগ করুন।"
        )
    else:
        reply = (
            "[Offline guidance] BloodPulse connects donors with emergency requests. "
            f"Basic donor criteria: age 18–60, weight >= 50 kg, and a minimum {days}-day interval since last donation. "
            "For urgent needs, create a request in Blood Hub or call 999 for medical emergencies."
        )
    return {
        'reply': reply,
        'emergency': False,
        'action_ids': ['open_search'],
        'matched_intent': 'general_guidance'
    }

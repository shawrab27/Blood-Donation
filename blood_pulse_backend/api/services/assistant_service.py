# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import csv
import logging
import os
import re
import time
from datetime import datetime
from django.conf import settings

logger = logging.getLogger(__name__)

STOPWORDS = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'can', 'i', 'you', 'he', 'she', 'it',
    'we', 'they', 'to', 'for', 'in', 'on', 'at', 'by', 'with', 'about', 'of', 'how',
    'what', 'when', 'where', 'which', 'who', 'why', 'do', 'does', 'did', 'my', 'your',
    'ami', 'ki', 'kivabe', 'kobe', 'amar', 'apni', 'amake', 'কি', 'কী', 'কে', 'কীভাবে',
    'কবে', 'আমি', 'আমার', 'আপনি', 'আপনার', 'এবং', 'ও', 'বা', 'না', 'হবে', 'করতে', 'পারি'
}

class PulseAIAssistant:
    """
    PulseAI Assistant Service for medical triage and blood donation Q&A.
    Standardized response contract fallback generator with clinical accuracy.
    """
    _instance = None
    _kb_entries = []

    def __init__(self):
        self._load_knowledge_base()

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _load_knowledge_base(self):
        csv_paths = [
            os.path.join(settings.BASE_DIR, 'data', 'blood_donation_knowledge.csv'),
            os.path.join(settings.BASE_DIR, 'api', 'data', 'blood_donation_knowledge.csv'),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'data', 'blood_donation_knowledge.csv'),
        ]
        
        loaded = False
        for path in csv_paths:
            if os.path.exists(path):
                try:
                    with open(path, mode='r', encoding='utf-8') as f:
                        reader = csv.DictReader(f)
                        self._kb_entries = list(reader)
                        logger.info(f"Loaded {len(self._kb_entries)} Q&A rows from {path}")
                        loaded = True
                        break
                except Exception as e:
                    logger.error(f"Error reading CSV at {path}: {e}")

        if not loaded:
            logger.warning("No CSV knowledge base found, using in-memory default rows.")
            self._kb_entries = [
                {
                    "question_en": "How long before next donation?",
                    "question_bn": "আমি কত দিন পর পর রক্ত দিতে পারব?",
                    "answer_en": "You can donate blood once every 90 days (13 weeks). This allows your body sufficient time to regenerate blood cells.",
                    "answer_bn": "আপনি প্রতি ৯০ দিন (১৩ সপ্তাহ) পর পর রক্ত দিতে পারবেন। এটি শরীরকে রক্তকণিকা পুনরায় তৈরি করতে সাহায্য করে।",
                    "category": "eligibility",
                    "confidence_score": "0.99"
                },
                {
                    "question_en": "Symptoms after donation?",
                    "question_bn": "রক্তদানের পর কী কী উপসর্গ হতে পারে?",
                    "answer_en": "Mild dizziness or tiredness is normal. Rest 15 mins, drink plenty of fluids, and avoid strenuous exercise.",
                    "answer_bn": "হালকা মাথা ঘোরা বা ক্লান্তি স্বাভাবিক। ১৫ মিনিট বিশ্রাম নিন, প্রচুর তরল পান করুন এবং ভারী কাজ পরিহার করুন।",
                    "category": "recovery",
                    "confidence_score": "0.98"
                },
                {
                    "question_en": "Blood type compatibility?",
                    "question_bn": "রক্তের গ্রুপের ম্যাচিং কেমন?",
                    "answer_en": "O- is universal donor for RBCs, O+ can give to all positive groups. AB+ is universal receiver.",
                    "answer_bn": "ও নেগেটিভ (O-) সার্বজনীন দাতা, ও পজিটিভ (O+) সব পজিটিভ গ্রুপকে দিতে পারে। এবি পজিটিভ (AB+) সার্বজনীন গ্রহীতা।",
                    "category": "blood_science",
                    "confidence_score": "0.99"
                },
                {
                    "question_en": "Emergency request process?",
                    "question_bn": "জরুরি রক্তের অনুরোধ কীভাবে করব?",
                    "answer_en": "Open Blood Hub -> Emergency -> Personal Emergency, fill in patient and hospital details, and submit.",
                    "answer_bn": "ব্লাড হাব -> ইমার্জেন্সি -> পার্সোনাল ইমার্জেন্সিতে গিয়ে রোগীর তথ্য ও হাসপাতালের বিবরণ পূরণ করে সাবমিট করুন।",
                    "category": "process",
                    "confidence_score": "0.99"
                }
            ]

    def _is_bangla(self, text: str) -> bool:
        return bool(re.search(r'[\u0980-\u09FF]', text))

    def _match_csv(self, query: str, is_bn: bool) -> dict | None:
        if not self._kb_entries:
            return None

        # Filter meaningful tokens (ignoring stopwords)
        tokens = {t for t in re.findall(r'\w+', query.lower()) if t not in STOPWORDS}
        if not tokens:
            tokens = set(re.findall(r'\w+', query.lower()))
            if not tokens:
                return None

        best_score = 0
        best_match = None

        for row in self._kb_entries:
            both_q = (row.get('question_en', '') + " " + row.get('question_bn', '')).lower()
            target_tokens = {t for t in re.findall(r'\w+', both_q) if t not in STOPWORDS}
            overlap = len(tokens.intersection(target_tokens))

            if overlap > best_score:
                best_score = overlap
                best_match = row

        if best_match and best_score >= 2:
            ans = best_match.get('answer_bn') if is_bn else best_match.get('answer_en')
            if not ans:
                ans = best_match.get('answer_en') or best_match.get('answer_bn')
            try:
                conf = float(best_match.get('confidence_score', 0.95))
            except (ValueError, TypeError):
                conf = 0.95

            return {
                "response": ans,
                "reply": ans,
                "source": "csv",
                "confidence": conf,
                "category": best_match.get('category', 'medical'),
            }

        return None

    def answer_query(self, query: str, lang: str = 'bn', profile_context: dict = None) -> dict:
        """
        Unified query entrypoint for PulseAI assistant.
        Enforces safety guard for users with incomplete profiles asking personal questions.
        """
        norm = (query or '').lower().strip()
        is_bn = (lang == 'bn') or self._is_bangla(norm)

        # Profile completeness guard for personal queries
        if profile_context is not None:
            is_complete = profile_context.get('is_profile_complete', True)
            blood_group = (profile_context.get('blood_group') or '').strip()
            if not is_complete or not blood_group:
                personal_kws = [
                    'who can give me', 'give me blood', 'can i donate', 'amake ke',
                    'রক্ত দিতে পারবে', 'রক্ত দিতে পারব', 'কে রক্ত দিতে পারবে', 'আমাকে কে',
                    'amake', 'আমাকে', 'my blood', 'আমার রক্ত', 'eligible', 'আমি কি', 'who can donate'
                ]
                if any(kw in norm for kw in personal_kws):
                    ans_en = "Your blood group is not set in your profile. Please complete registration."
                    ans_bn = "আপনার প্রোফাইলে রক্তের গ্রুপ নির্ধারণ করা নেই। অনুগ্রহ করে রেজিস্ট্রেশন সম্পূর্ণ করুন।"
                    reply = ans_bn if is_bn else ans_en
                    self._log_event("incomplete_profile_guard")
                    return {
                        "answer_en": ans_en,
                        "answer_bn": ans_bn,
                        "response": reply,
                        "reply": reply,
                        "source": "guard_incomplete_profile",
                        "confidence": 1.0,
                        "language": 'bn' if is_bn else 'en',
                        "emergency": False,
                        "needs_human": False,
                        "action": "complete_profile",
                    }

        return self.get_response(query, language=lang)

    def get_response(self, message: str, language: str = 'bn') -> dict:
        """
        Fallback response generator complying with the standard response contract:
        1-2 sentence direct answer first, max 6 bullets, blood bank / doctor note, <= 180 words.
        """
        is_bn = (language == 'bn') or self._is_bangla(message)
        norm = message.lower().strip()

        # Handle common general query: "how can I donate blood" / "কীভাবে রক্ত দেব"
        donation_kws = ['how can i donate', 'how to donate', 'donate blood', 'রক্ত দান', 'কীভাবে রক্ত', 'রক্ত দিতে চাই', 'রক্ত দেব']
        if any(kw in norm for kw in donation_kws):
            if is_bn:
                reply = (
                    "ব্লাডপালসের মাধ্যমে রক্তদান করার জন্য প্রাথমিক যোগ্যতা নিশ্চিত করে নিচের ধাপগুলো অনুসরণ করুন:\n\n"
                    "• বয়স ১৮ থেকে ৬০ বছর এবং শারীরিক ওজন কমপক্ষে ৫০ কেজি হতে হবে।\n"
                    "• সুস্থ ও নীরোগ থাকতে হবে; বিগত ১৪ দিনের মধ্যে জ্বর, ঠান্ডা বা সংক্রামক রোগ থাকা যাবে না।\n"
                    "• হিমোগ্লোবিনের মাত্রা স্বাভাবিক (কমপক্ষে ১২.৫ গ্রাম/ডিএল) থাকতে হবে।\n"
                    "• রক্তদানের ২-৩ ঘণ্টা পূর্বে পুষ্টিকর খাবার গ্রহণ এবং পর্যাপ্ত পানি পান করুন।\n"
                    "• পূর্ববর্তী রক্তদানের পর থেকে ন্যূনতম ৯০ দিন (১৩ সপ্তাহ) বিরতি থাকতে হবে।\n\n"
                    "রক্তদানের পূর্বে ব্লাড ব্যাংকের দায়িত্বরত চিকিৎসকের কাছে স্বাস্থ্য পরীক্ষা করিয়ে নিন।"
                )
            else:
                reply = (
                    "To donate blood through BloodPulse, make sure you meet the general donor eligibility criteria and follow these steps:\n\n"
                    "• Be between 18 and 60 years of age and weigh at least 50 kg.\n"
                    "• Feel healthy and symptom-free, with no fever or flu in the last 14 days.\n"
                    "• Maintain a hemoglobin level of at least 12.5 g/dL.\n"
                    "• Drink plenty of water and have a light meal 2 to 3 hours before donating.\n"
                    "• Ensure at least 90 days (13 weeks) have passed since your last whole blood donation.\n\n"
                    "Please confirm final medical clearance at your local blood bank prior to donation."
                )
            self._log_event("fallback_direct_donation_match")
            return {
                "response": reply,
                "reply": reply,
                "source": "standard_contract",
                "confidence": 0.99,
                "language": 'bn' if is_bn else 'en',
                "emergency": False,
                "needs_human": False,
            }

        # 1. Fallback: CSV Matching (with filtered stopwords)
        csv_result = self._match_csv(message, is_bn)
        if csv_result:
            csv_result['language'] = 'bn' if is_bn else 'en'
            self._log_event("csv_match")
            return csv_result

        # 2. Last Resort: Structured Clinical Guidance
        if is_bn:
            default_reply = (
                "ব্লাডপালস নিরাপদ রক্তদান ও জরুরি ডোনার সংযোগে ২৪/৭ আপনার পাশে রয়েছে:\n\n"
                "• রক্তদানের ন্যূনতম বিরতি কঠোরভাবে ৯০ দিন (১৩ সপ্তাহ)।\n"
                "• রক্তদাতার বয়স ১৮-৬০ বছর এবং ওজন কমপক্ষে ৫০ কেজি হতে হবে।\n"
                "• অ্যাপের ব্লাড হাব থেকে জরুরি প্রয়োজনে রক্তের রিকুয়েস্ট পোস্ট করতে পারেন।\n"
                "• যেকোনো জটিল বা জরুরি অসুস্থতায় অবিলম্বে ৯৯৯ নম্বরে যোগাযোগ করুন।\n\n"
                "রক্তদানের পূর্বে সবসময় সংশ্লিষ্ট ব্লাড ব্যাংকে ব্যক্তিগত যোগ্যতা যাচাই করুন।"
            )
        else:
            default_reply = (
                "BloodPulse provides 24/7 clinical guidance and emergency donor mobilization:\n\n"
                "• The mandatory interval between whole blood donations is strictly 90 days.\n"
                "• Donors must be 18–60 years old and weigh at least 50 kg.\n"
                "• You can post or search emergency requests anytime via Blood Hub.\n"
                "• For life-threatening emergencies, dial 999 or go to the nearest ER immediately.\n\n"
                "Please confirm all individual eligibility criteria at your nearest blood bank."
            )

        res = {
            "response": default_reply,
            "reply": default_reply,
            "source": "default_structured",
            "confidence": 0.90,
            "language": 'bn' if is_bn else 'en',
            "emergency": False,
            "needs_human": False,
        }
        self._log_event("default_structured_fallback")
        return res

    def _log_event(self, source: str):
        # Technical log ONLY without storing user message text or PII
        logger.info(f"[{datetime.utcnow().isoformat()}] PulseAI fallback event: source={source}")

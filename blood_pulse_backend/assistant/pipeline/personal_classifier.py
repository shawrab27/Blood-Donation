# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Deterministic Classifier and Handlers for Personal User Inquiries & Fare Estimation.
Handles:
1. "Who can give me blood?" (Aggregate eligible donor count per district, NO names/phones/locations).
2. "When can I donate?" / "Can I donate?" (SERVER-evaluated eligibility, days left on DONOR_COOLDOWN_DAYS, last donation date).
3. "My blood group" (Returns profile blood group or prompt to set).
4. "My donation history" / "Donations completed" (Verified donations count).
5. Fare estimator: Haversine distance x road factor (1.3) x rate range (15-20 BDT/km).
"""

import math
import re
from datetime import date, timedelta
from django.conf import settings
from django.utils import timezone
from api.conf import DONOR_COOLDOWN_DAYS
from api.services.eligibility import evaluate_donor_eligibility


# Common misspellings and transliterations in Bangla and English
PERSONAL_QUESTION_PATTERNS = {
    'who_can_give_blood': [
        r'\bwho\s+can\s+give\s+(?:me\s+)?blood\b',
        r'\bwho\s+can\s+donate\s+to\s+me\b',
        r'\bcan\s+anyone\s+give\s+me\s+blood\b',
        r'কে\s+(?:আমাকে\s+)?রক্ত\s+(?:দিতে\s+)?পারবে',
        r'আমাকে\s+কে\s+রক্ত\s+দিবে',
        r'কে\s+রক্ত\s+দিব[েন|ে]',
        r'amake\s+ke\s+rokt?o?\s+dibe',
        r'ke\s+rokt?o?\s+dite\s+parbe',
    ],
    'when_can_i_donate': [
        r'\bwhen\s+can\s+i\s+donate\b',
        r'\bcan\s+i\s+donate\b',
        r'\bam\s+i\s+eligible\b',
        r'\bnext\s+donation\b',
        r'\bhow\s+many\s+days\s+(?:left\s+)?(?:until|before|to)\s+donate\b',
        r'কবে\s+রক্ত\s+দিতে\s+পারব[ো|ি]?',
        r'কখন\s+রক্ত\s+দিতে\s+পারব[ো|ি]?',
        r'আমি\s+কি\s+রক্ত\s+দিতে\s+পারব[ো|ি]?',
        r'আমার\s+রক্তদানের\s+যোগ্যতা',
        r'kobe\s+rokt?o?\s+dite\s+parb[oi]?',
        r'ami\s+ki\s+rokt?o?\s+dite\s+parb[oi]?',
    ],
    'my_blood_group': [
        r'\bmy\s+blood\s+group\b',
        r'\bwhat\s+is\s+my\s+blood\s+group\b',
        r'আমার\s+রক্তের\s+গ্রুপ',
        r'amar\s+rokter\s+group',
        r'amar\s+blood\s+group',
    ],
    'my_donation_history': [
        r'\bmy\s+donation\s+history\b',
        r'\bhow\s+many\s+times\s+have\s+i\s+donated\b',
        r'\bmy\s+donations\b',
        r'\bdonations\s+completed\b',
        r'আমার\s+রক্তদানের\s+ইতিহাস',
        r'আমি\s+কতবার\s+রক্ত\s+দিয়েছি',
        r'কতবার\s+রক্ত\s+দান\s+করেছি',
        r'amar\s+donation\s+history',
        r'ami\s+kotobar\s+rokt?o?\s+diy[e|i]chi',
    ],
    'fare_estimate': [
        r'\bfare\s+estimate\b',
        r'\bhow\s+much\s+(?:is\s+the\s+)?(?:fare|cost|rent)\b',
        r'\btransport\s+(?:fare|cost)\b',
        r'\bambulance\s+fare\b',
        r'\bcng\s+fare\b',
        r'ভাড়া\s+কত',
        r'যাতায়াত\s+ভাড়া',
        r'গাড়ি\s+ভাড়া',
        r'সিএনজি\s+ভাড়া',
        r'ভাড়ার\s+পরিমাণ',
        r'vara\s+koto',
        r'bhara\s+koto',
        r'cng\s+vara',
    ]
}


def classify_personal_query(text: str) -> str | None:
    """
    Deterministically classify the query into one of the personal intent categories.
    Does NOT invoke LLM. Handles English, Bangla Unicode, and common phonetic/regional spellings.
    """
    if not text:
        return None
    cleaned = text.strip().lower()
    for intent, patterns in PERSONAL_QUESTION_PATTERNS.items():
        for pat in patterns:
            if re.search(pat, cleaned, re.IGNORECASE):
                return intent
    return None


def is_personal_query(text: str) -> bool:
    """Returns True if the text asks about the user's personal profile, eligibility, or history."""
    return classify_personal_query(text) is not None


# Compatible blood donor mapping
DONOR_COMPATIBILITY = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
}


def handle_personal_query(intent: str, user, locale: str = 'bn', query_text: str = '') -> dict:
    """
    Evaluates server data deterministically for the user and formats a safe response.
    Zero PII guarantee: NEVER exposes names, phone numbers, or exact coordinates of donors.
    """
    is_bn = (locale == 'bn') or bool(re.search(r'[\u0980-\u09FF]', query_text))
    from api.models import DonorProfile

    profile = getattr(user, 'donorprofile', None) or DonorProfile.objects.filter(user=user).first()
    is_comp, missing = profile.check_is_complete() if profile else (False, ["blood_group", "district", "phone_number"])

    if not is_comp:
        msg = (
            "আপনার প্রোফাইলে রক্তের গ্রুপ নির্ধারণ করা নেই। অনুগ্রহ করে রেজিস্ট্রেশন সম্পূর্ণ করুন।"
            if is_bn else
            "Your blood group is not set in your profile. Please complete registration."
        )
        return {
            "reply": msg,
            "response": msg,
            "source": "fixed_incomplete_profile",
            "confidence": 1.0,
            "language": "bn" if is_bn else "en",
            "emergency": False,
            "action": "complete_profile",
            "actions": [{'id': 'complete_profile', 'label_en': 'Complete Profile', 'label_bn': 'প্রোফাইল সম্পূর্ণ করুন', 'route': '/profile/complete'}],
            "missing_fields": missing,
            "needs_human": False,
            "flags": ["INCOMPLETE_PROFILE"]
        }

    # Intent 1: "Who can give me blood?"
    if intent == 'who_can_give_blood':
        blood_group = profile.blood_group
        district_name = (profile.district or '').strip()
        compatible_groups = DONOR_COMPATIBILITY.get(blood_group, [blood_group])

        # Server-side query for count of available donors in user's district
        qs = DonorProfile.objects.filter(
            blood_group__in=compatible_groups,
            is_available=True,
            is_suspended=False,
        )
        if district_name:
            qs = qs.filter(district__iexact=district_name)

        # Exclude self
        if profile:
            qs = qs.exclude(id=profile.id)

        # Filter eligibility (cooldown check)
        from django.db.models import Q
        cooldown_threshold = timezone.now().date() - timedelta(days=DONOR_COOLDOWN_DAYS)
        eligible_count = qs.filter(
            Q(last_donation_date__isnull=True) | Q(last_donation_date__lte=cooldown_threshold)
        ).count()

        if is_bn:
            reply = (
                f"আপনার রক্তের গ্রুপ {blood_group}। {district_name or 'আপনার এলাকায়'} এই মুহূর্তে "
                f"প্রায় {eligible_count} জন উপযুক্ত রক্তদাতা নিবন্ধিত আছেন। "
                f"জরুরি রক্তের প্রয়োজনে ব্লাড হাবে রিকোয়েস্ট তৈরি করুন।"
            )
        else:
            reply = (
                f"Your blood group is {blood_group}. Currently, there are {eligible_count} eligible "
                f"donor(s) registered in {district_name or 'your district'}. "
                f"For urgent requirements, please create a request in Blood Hub."
            )

        return {
            "reply": reply,
            "response": reply,
            "source": "server_aggregate_donors",
            "confidence": 1.0,
            "language": "bn" if is_bn else "en",
            "emergency": False,
            "actions": [{'id': 'open_blood_hub', 'label_en': 'Open Blood Hub', 'label_bn': 'ব্লাড হাবে যান', 'route': '/blood-hub'}],
            "needs_human": False,
            "flags": ["AGGREGATE_DONORS_ONLY"]
        }

    # Intent 2: "When can I donate?"
    if intent == 'when_can_i_donate':
        last_date = profile.last_donation_date
        elig_result = evaluate_donor_eligibility(profile)

        if elig_result.get('is_eligible'):
            if is_bn:
                reply = "আপনি আজই রক্ত দান করার জন্য উপযুক্ত! আপনার শারীরিক সুস্থতা থাকলে ব্লাড হাবে সক্রিয় রিকোয়েস্টে সাহায্য করতে পারেন।"
            else:
                reply = "You are eligible to donate blood today! If you are feeling healthy, you can assist active requests in Blood Hub."
        else:
            days_left = elig_result.get('days_remaining', 0)
            if last_date and days_left > 0:
                next_date = last_date + timedelta(days=DONOR_COOLDOWN_DAYS)
                date_str = next_date.strftime('%d %B %Y')
                if is_bn:
                    reply = (
                        f"আপনার সর্বশেষ রক্তদানের তারিখ ছিল {last_date.strftime('%d %B %Y')}। "
                        f"৯০ দিনের কুলডাউন অনুযায়ী আপনি আর {days_left} দিন পর ({date_str}) আবার রক্ত দান করতে পারবেন।"
                    )
                else:
                    reply = (
                        f"Your last donation date was {last_date.strftime('%d %B %Y')}. "
                        f"Based on the 90-day cooldown period, you will be eligible in {days_left} day(s) on {date_str}."
                    )
            else:
                reason = elig_result.get('reason', 'Eligibility criteria not met.')
                if is_bn:
                    reply = f"এই মুহূর্তে আপনি রক্তদানের জন্য উপযুক্ত নন: {reason}"
                else:
                    reply = f"You are not eligible to donate at this moment: {reason}"

        return {
            "reply": reply,
            "response": reply,
            "source": "server_donor_eligibility",
            "confidence": 1.0,
            "language": "bn" if is_bn else "en",
            "emergency": False,
            "actions": [{'id': 'open_profile', 'label_en': 'View Profile', 'label_bn': 'প্রোফাইল দেখুন', 'route': '/profile'}],
            "needs_human": False,
            "flags": ["SERVER_ELIGIBILITY"]
        }

    # Intent 3: "My blood group"
    if intent == 'my_blood_group':
        bg = profile.blood_group
        if is_bn:
            reply = f"আপনার প্রোফাইলে সংরক্ষিত রক্তের গ্রুপ হলো {bg}।"
        else:
            reply = f"Your recorded blood group in BloodPulse is {bg}."

        return {
            "reply": reply,
            "response": reply,
            "source": "server_donor_profile",
            "confidence": 1.0,
            "language": "bn" if is_bn else "en",
            "emergency": False,
            "actions": [{'id': 'open_profile', 'label_en': 'View Profile', 'label_bn': 'প্রোফাইল দেখুন', 'route': '/profile'}],
            "needs_human": False,
            "flags": ["SERVER_PROFILE_DATA"]
        }

    # Intent 4: "My donation history"
    if intent == 'my_donation_history':
        donations_count = profile.total_bags_donated
        last_date = profile.last_donation_date
        last_str = last_date.strftime('%d %B %Y') if last_date else ('কোনো তথ্য নেই' if is_bn else 'None')

        if is_bn:
            reply = (
                f"আপনি এ পর্যন্ত BloodPulse-এ সফলভাবে {donations_count} বার রক্ত দান সম্পন্ন করেছেন। "
                f"সর্বশেষ রক্তদানের তারিখ: {last_str}।"
            )
        else:
            reply = (
                f"You have completed {donations_count} verified blood donation(s) on BloodPulse. "
                f"Last recorded donation: {last_str}."
            )

        return {
            "reply": reply,
            "response": reply,
            "source": "server_donation_history",
            "confidence": 1.0,
            "language": "bn" if is_bn else "en",
            "emergency": False,
            "actions": [{'id': 'open_profile', 'label_en': 'View Profile', 'label_bn': 'প্রোফাইল দেখুন', 'route': '/profile'}],
            "needs_human": False,
            "flags": ["SERVER_HISTORY_DATA"]
        }

    return None


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Computes great-circle distance between two GPS coordinates in kilometers."""
    R = 6371.0 # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def estimate_fare_range(
    distance_km: float | None = None,
    lat1: float | None = None, lon1: float | None = None,
    lat2: float | None = None, lon2: float | None = None,
    locale: str = 'bn'
) -> dict:
    """
    Deterministic Fare Estimator:
    - Distance: Haversine distance x road factor (default 1.3).
    - Rate range: Configurable (default 15-20 BDT/km, approximate local CNG/auto rate).
    - Always returns a RANGE with strict disclaimer.
    - Zero external routing dependencies, zero coordinate logging.
    """
    is_bn = (locale == 'bn')

    if distance_km is None:
        if None in (lat1, lon1, lat2, lon2):
            msg = (
                "দূরত্ব গণনা করা যায়নি। অনুগ্রহ করে নির্দিষ্ট গন্তব্য ও অবস্থান উল্লেখ করুন।"
                if is_bn else
                "Unable to calculate distance. Please specify locations or enable location access."
            )
            return {
                "reply": msg,
                "response": msg,
                "source": "fare_estimator_no_distance",
                "confidence": 1.0,
                "language": "bn" if is_bn else "en",
                "emergency": False,
                "fare_range": None,
                "disclaimer": "Approximate. Real fares vary by time, weather and vehicle.",
                "actions": [],
            }
        straight_dist = haversine_distance_km(lat1, lon1, lat2, lon2)
        road_factor = getattr(settings, 'FARE_ROAD_FACTOR', 1.3)
        distance_km = straight_dist * road_factor

    road_dist = round(distance_km, 1)
    min_rate = getattr(settings, 'FARE_MIN_RATE_PER_KM', 15)
    max_rate = getattr(settings, 'FARE_MAX_RATE_PER_KM', 20)

    min_fare = int(math.ceil(road_dist * min_rate))
    max_fare = int(math.ceil(road_dist * max_rate))

    # Base minimum fare clamp (e.g. 50 BDT)
    min_fare = max(min_fare, 50)
    max_fare = max(max_fare, 70)

    disclaimer_bn = "আনুমানিক হিসাব (সিএনজি/অটো)। সময়, আবহাওয়া এবং যানবাহনের ধরনভেদে প্রকৃত ভাড়া কম-বেশি হতে পারে।"
    disclaimer_en = "Approximate. Real fares vary by time, weather and vehicle."

    if is_bn:
        reply = (
            f"আনুমানিক দূরত্ব: প্রায় {road_dist} কিমি (সড়ক পথ)।\n"
            f"ভাড়ার সম্ভাব্য পরিসীমা: ৳{min_fare} - ৳{max_fare} (সিএনজি / অটো রেট)।\n"
            f"সতর্কতা: {disclaimer_bn}"
        )
    else:
        reply = (
            f"Estimated road distance: approx {road_dist} km.\n"
            f"Estimated fare range: ৳{min_fare} - ৳{max_fare} (approx local CNG/auto rate).\n"
            f"Notice: {disclaimer_en}"
        )

    return {
        "reply": reply,
        "response": reply,
        "source": "fare_estimator",
        "confidence": 1.0,
        "language": "bn" if is_bn else "en",
        "emergency": False,
        "distance_km": road_dist,
        "fare_range": f"{min_fare}-{max_fare} BDT",
        "min_fare_bdt": min_fare,
        "max_fare_bdt": max_fare,
        "disclaimer": disclaimer_en,
        "actions": [],
        "flags": ["FARE_ESTIMATE_RANGE"]
    }

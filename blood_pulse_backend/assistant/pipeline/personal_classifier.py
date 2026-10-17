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
        r'\bfind\s+blood\s+donors\b',
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
        r'\bcooldown\s+period\b',
        r'\bnext\s+donation\b',
        r'\bhow\s+many\s+days\s+(?:left\s+)?(?:until|before|to)\s+donate\b',
        r'কবে\s+রক্ত\s+দিতে\s+পারব[ো|ি]?',
        r'কখন\s+রক্ত\s+দিতে\s+পারব[ো|ি]?',
        r'কতদিন\s+পর',
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
        r'আমার\s+ডোনেশন\s+হিস্ট্রি',
        r'আমি\s+কতবার\s+রক্ত\s+দিয়েছি',
        r'আমি\s+কতবার\s+রক্ত\s+দিয়েছি',
        r'কতবার\s+রক্ত\s+দান\s+করেছি',
        r'amar\s+donation\s+history',
        r'ami\s+kotobar\s+rokt?o?\s+diy[e|i]chi',
    ],
    'fare_estimate': [
        r'\bfare\s+estimate\b',
        r'\bfare\s+from\b',
        r'\b(?:travel|road|transport)\s+fare\b',
        r'\bhow\s+much\s+(?:is\s+the\s+)?(?:fare|cost|rent)\b',
        r'\b(?:bus|cng|auto|taxi|ambulance|car)\s+(?:fare|cost|rent)\b',
        r'\bfare\b',
        r'ভাড়া\s+কত',
        r'ভাড়া\s+কত',
        r'যাতায়াত\s+ভাড়া',
        r'গাড়ি\s+ভাড়া',
        r'সিএনজি\s+ভাড়া',
        r'সিএনজি\s+ভাড়া',
        r'ভাড়ার\s+পরিমাণ',
        r'থেকে.+ভাড়[া|ায়]',
        r'থেকে.+ভাড়[া|ায়]',
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


import math
import re
from datetime import date, timedelta
from django.conf import settings
from django.utils import timezone
from api.conf import (
    DONOR_COOLDOWN_DAYS,
    FARE_ROAD_FACTOR,
    FARE_MIN_RATE_PER_KM,
    FARE_MAX_RATE_PER_KM,
    FARE_MIN_BASE_FARE,
    FARE_MAX_BASE_FARE,
)
from api.services.eligibility import evaluate_donor_eligibility, get_eligible_donors_base_queryset
from api.services.compat import get_compatible_donor_groups


# Canonical centroids for Bangladesh 64 Districts (Internal static table, zero external API)
DISTRICT_CENTROIDS = {
    'Dhaka': (23.8103, 90.4125),
    'Faridpur': (23.6070, 89.8429),
    'Gazipur': (24.0023, 90.4264),
    'Gopalganj': (23.0051, 89.8266),
    'Kishoreganj': (24.4449, 90.7766),
    'Madaripur': (23.1641, 90.1897),
    'Manikganj': (23.8644, 90.0047),
    'Munshiganj': (23.5422, 90.5305),
    'Narayanganj': (23.6238, 90.5000),
    'Narsingdi': (23.9197, 90.7202),
    'Rajbari': (23.7574, 89.6445),
    'Shariatpur': (23.2423, 90.4348),
    'Tangail': (24.2513, 89.9167),
    'Bandarban': (22.1953, 92.2184),
    'Brahmanbaria': (23.9571, 91.1119),
    'Chandpur': (23.2333, 90.6667),
    'Chattogram': (22.3569, 91.7832),
    "Cox's Bazar": (21.4272, 92.0058),
    'Cumilla': (23.4607, 91.1809),
    'Feni': (23.0186, 91.3966),
    'Khagrachhari': (23.1193, 91.9847),
    'Lakshmipur': (22.9425, 90.8412),
    'Noakhali': (22.8696, 91.0994),
    'Rangamati': (22.7324, 92.2985),
    'Bogura': (24.8465, 89.3777),
    'Chapai Nawabganj': (24.5965, 88.2775),
    'Joypurhat': (25.1015, 89.0270),
    'Naogaon': (24.7936, 88.9318),
    'Natore': (24.4206, 88.9324),
    'Pabna': (24.0064, 89.2372),
    'Rajshahi': (24.3745, 88.6042),
    'Sirajganj': (24.4534, 89.7008),
    'Bagerhat': (22.6516, 89.7859),
    'Chuadanga': (23.6402, 88.8418),
    'Jashore': (23.1664, 89.2081),
    'Jhenaidah': (23.5448, 89.1539),
    'Khulna': (22.8456, 89.5403),
    'Kushtia': (23.9013, 89.1205),
    'Magura': (23.4873, 89.4199),
    'Meherpur': (23.7622, 88.6318),
    'Narail': (23.1725, 89.5127),
    'Satkhira': (22.7185, 89.0705),
    'Barguna': (22.0953, 90.1121),
    'Barishal': (22.7010, 90.3535),
    'Bhola': (22.6859, 90.6481),
    'Jhalokati': (22.6406, 90.1987),
    'Patuakhali': (22.3596, 90.3299),
    'Pirojpur': (22.5841, 89.9720),
    'Habiganj': (24.3749, 91.4155),
    'Moulvibazar': (24.4829, 91.7774),
    'Sunamganj': (25.0658, 91.3950),
    'Sylhet': (24.8949, 91.8687),
    'Dinajpur': (25.6217, 88.6355),
    'Gaibandha': (25.3288, 89.5403),
    'Kurigram': (25.8054, 89.6362),
    'Lalmonirhat': (25.9923, 89.2847),
    'Nilphamari': (25.9318, 88.8560),
    'Panchagarh': (26.3411, 88.5542),
    'Rangpur': (25.7439, 89.2752),
    'Thakurgaon': (26.0337, 88.4617),
    'Jamalpur': (24.9375, 89.9378),
    'Mymensingh': (24.7471, 90.4203),
    'Netrokona': (24.8709, 90.7279),
    'Sherpur': (25.0205, 90.0153),
}


def get_district_coordinates(district_name: str) -> tuple[float, float] | None:
    """Returns canonical centroid coordinates (lat, lon) for a district or known alias."""
    if not district_name:
        return None
    from api.data.bd_locations import DISTRICT_ALIASES
    canonical = DISTRICT_ALIASES.get(district_name.strip(), district_name.strip())
    # Case-insensitive lookup
    for dist, coords in DISTRICT_CENTROIDS.items():
        if dist.lower() == canonical.lower():
            return coords
    return None


def handle_personal_query(intent: str, user, locale: str = 'bn', query_text: str = '') -> dict:
    """
    Evaluates server data deterministically for the user and formats a safe response.
    Zero PII guarantee: NEVER exposes names, phone numbers, or exact coordinates of donors.
    """
    is_bn = (locale == 'bn') or bool(re.search(r'[\u0980-\u09FF]', query_text))
    from api.models import DonorProfile, DonationMatch

    profile = getattr(user, 'donorprofile', None) or DonorProfile.objects.filter(user=user).first()
    is_comp, missing = profile.check_is_complete() if profile else (False, ["blood_group", "district", "phone_number"])

    # Confirm guard checks real is_profile_complete flag
    real_profile_complete = getattr(profile, 'is_profile_complete', False)
    if not (real_profile_complete and is_comp and profile and profile.blood_group):
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

        # Enforce unified shared eligibility function across Blood Hub (snooze, cooldown, suspended, active)
        base_qs = get_eligible_donors_base_queryset(
            blood_group=blood_group,
            component='WHOLE',
            for_search=False,
            now=timezone.now(),
        )

        if district_name:
            base_qs = base_qs.filter(district__iexact=district_name)

        if profile:
            base_qs = base_qs.exclude(id=profile.id)

        eligible_count = base_qs.count()

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

    # Intent 4: "My donation history" (Must count ONLY two-sided confirmed donations)
    if intent == 'my_donation_history':
        confirmed_count = DonationMatch.objects.filter(
            donor=profile,
            confirmed_at__isnull=False
        ).count()
        last_match = DonationMatch.objects.filter(
            donor=profile,
            confirmed_at__isnull=False
        ).order_by('-confirmed_at').first()

        last_date = last_match.confirmed_at.date() if last_match and last_match.confirmed_at else profile.last_donation_date
        last_str = last_date.strftime('%d %B %Y') if last_date else ('কোনো তথ্য নেই' if is_bn else 'None')

        if is_bn:
            reply = (
                f"আপনি এ পর্যন্ত BloodPulse-এ সফলভাবে {confirmed_count} বার রক্ত দান সম্পন্ন করেছেন। "
                f"সর্বশেষ রক্তদানের তারিখ: {last_str}।"
            )
        else:
            reply = (
                f"You have completed {confirmed_count} verified blood donation(s) on BloodPulse. "
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


DEFAULT_VEHICLE_RATES = {
    'dhaka': {
        'cng': {'min_base': 40, 'max_base': 50, 'min_km': 15, 'max_km': 20, 'speed': 20, 'name_en': 'CNG / Auto', 'name_bn': 'সিএনজি / অটো'},
        'rickshaw': {'min_base': 25, 'max_base': 35, 'min_km': 15, 'max_km': 25, 'speed': 12, 'max_dist': 6.0, 'name_en': 'Rickshaw', 'name_bn': 'রিকশা'},
        'bike': {'min_base': 30, 'max_base': 40, 'min_km': 12, 'max_km': 18, 'speed': 25, 'name_en': 'Bike Ride-share', 'name_bn': 'বাইক রাইড-শেয়ার'},
        'car': {'min_base': 80, 'max_base': 120, 'min_km': 25, 'max_km': 35, 'speed': 18, 'name_en': 'Car / Taxi', 'name_bn': 'গাড়ি / ক্যাব'},
        'bus': {'min_base': 15, 'max_base': 20, 'min_km': 2.5, 'max_km': 3.5, 'speed': 15, 'name_en': 'City Bus', 'name_bn': 'সিটি বাস'},
        'ambulance': {'min_base': 1000, 'max_base': 1500, 'min_km': 35, 'max_km': 50, 'speed': 30, 'name_en': 'Ambulance (Emergency)', 'name_bn': 'জরুরি অ্যাম্বুলেন্স'},
    },
    'chattogram': {
        'cng': {'min_base': 35, 'max_base': 45, 'min_km': 14, 'max_km': 18, 'speed': 22, 'name_en': 'CNG / Auto', 'name_bn': 'সিএনজি / অটো'},
        'rickshaw': {'min_base': 20, 'max_base': 30, 'min_km': 15, 'max_km': 20, 'speed': 12, 'max_dist': 6.0, 'name_en': 'Rickshaw', 'name_bn': 'রিকশা'},
        'bike': {'min_base': 25, 'max_base': 35, 'min_km': 10, 'max_km': 15, 'speed': 25, 'name_en': 'Bike Ride-share', 'name_bn': 'বাইক রাইড-শেয়ার'},
        'car': {'min_base': 70, 'max_base': 100, 'min_km': 22, 'max_km': 30, 'speed': 20, 'name_en': 'Car / Taxi', 'name_bn': 'গাড়ি / ক্যাব'},
        'bus': {'min_base': 12, 'max_base': 18, 'min_km': 2.2, 'max_km': 3.0, 'speed': 18, 'name_en': 'Local Bus', 'name_bn': 'লোকাল বাস'},
        'ambulance': {'min_base': 900, 'max_base': 1400, 'min_km': 30, 'max_km': 45, 'speed': 30, 'name_en': 'Ambulance (Emergency)', 'name_bn': 'জরুরি অ্যাম্বুলেন্স'},
    },
    'other': {
        'cng': {'min_base': 30, 'max_base': 40, 'min_km': 12, 'max_km': 16, 'speed': 25, 'name_en': 'CNG / Auto', 'name_bn': 'সিএনজি / অটো'},
        'rickshaw': {'min_base': 15, 'max_base': 25, 'min_km': 10, 'max_km': 18, 'speed': 12, 'max_dist': 6.0, 'name_en': 'Rickshaw / Easybike', 'name_bn': 'রিকশা / ইজিবাইক'},
        'bike': {'min_base': 20, 'max_base': 30, 'min_km': 10, 'max_km': 14, 'speed': 30, 'name_en': 'Bike', 'name_bn': 'বাইক'},
        'car': {'min_base': 60, 'max_base': 90, 'min_km': 20, 'max_km': 28, 'speed': 30, 'name_en': 'Car / Microbus', 'name_bn': 'কার / মাইক্রোবাস'},
        'bus': {'min_base': 10, 'max_base': 15, 'min_km': 2.0, 'max_km': 2.8, 'speed': 25, 'name_en': 'Bus', 'name_bn': 'বাস'},
        'ambulance': {'min_base': 800, 'max_base': 1200, 'min_km': 25, 'max_km': 40, 'speed': 35, 'name_en': 'Ambulance (Emergency)', 'name_bn': 'জরুরি অ্যাম্বুলেন্স'},
    },
}

DHAKA_KEYWORDS = {'dhaka', 'ঢাকা', 'gazipur', 'গাজীপুর', 'narayanganj', 'নারায়ণগঞ্জ', 'savar', 'সাভার', 'uttara', 'উত্তরা', 'mirpur', 'মিরপুর', 'dhanmondi', 'ধানমন্ডি', 'gulshan', 'গুলশান', 'banani', 'বনানী', 'motijheel', 'মতিঝিল'}
CHATTOGRAM_KEYWORDS = {'chattogram', 'চট্টগ্রাম', 'chittagong', 'cox\'s bazar', 'কক্সবাজার', 'cumilla', 'কুমিল্লা', 'feni', 'ফেনী'}


def detect_city_group(place_from: str | None = None, place_to: str | None = None, lat: float | None = None, lon: float | None = None) -> str:
    """Detects city group (dhaka, chattogram, other) for vehicle rate estimation."""
    for p in (place_from or '', place_to or ''):
        p_clean = p.strip().lower()
        if any(k in p_clean for k in DHAKA_KEYWORDS):
            return 'dhaka'
        if any(k in p_clean for k in CHATTOGRAM_KEYWORDS):
            return 'chattogram'

    if lat is not None and lon is not None:
        if 23.4 <= lat <= 24.3 and 90.1 <= lon <= 90.8:
            return 'dhaka'
        if 21.8 <= lat <= 22.8 and 91.5 <= lon <= 92.3:
            return 'chattogram'

    return 'dhaka' if (not place_from and not place_to) else 'other'


def estimate_fare_range(
    distance_km: float | None = None,
    lat1: float | None = None, lon1: float | None = None,
    lat2: float | None = None, lon2: float | None = None,
    place_from: str | None = None, place_to: str | None = None,
    locale: str = 'bn',
    query_text: str = ''
) -> dict:
    """
    Deterministic Fare & Travel Time Estimator:
    - Calculates distance using Haversine with road curvature factor (FARE_ROAD_FACTOR).
    - City group aware (Dhaka, Chattogram, Other Districts).
    - Reads admin-editable VehicleFareRate from database if available, falls back to in-memory dataset.
    - Estimates fares and travel times for Rickshaw, CNG/Auto, Bike, Car, Bus, and Emergency Ambulance.
    - Strict disclaimer: All figures are ESTIMATES and placeholders for review.
    """
    is_bn = (locale == 'bn')

    if distance_km is None:
        # Check place names if provided
        if place_from and place_to:
            coords1 = get_district_coordinates(place_from)
            coords2 = get_district_coordinates(place_to)
            if not coords1 or not coords2:
                unknown = place_from if not coords1 else place_to
                msg = (
                    f"'{unknown}' স্থানটির ভৌগোলিক তথ্য পাওয়া যায়নি। অনুগ্রহ করে পরিচিত জেলা বা শহরের নাম উল্লেখ করুন।"
                    if is_bn else
                    f"Location '{unknown}' is not recognized. Please specify a known district name or provide distance."
                )
                return {
                    "reply": msg,
                    "response": msg,
                    "source": "fare_estimator_unknown_place",
                    "confidence": 1.0,
                    "language": "bn" if is_bn else "en",
                    "emergency": False,
                    "fare_range": None,
                    "disclaimer": "Approximate. Real fares vary by time, weather and vehicle.",
                    "actions": [],
                }
            lat1, lon1 = coords1
            lat2, lon2 = coords2

        if None in (lat1, lon1, lat2, lon2):
            msg = (
                "দূরত্ব গণনা করা যায়নি। অনুগ্রহ করে নির্দিষ্ট জেলা বা স্থান উল্লেখ করুন (যেমন: 'ঢাকা থেকে গাজীপুর ভাড়া কত')।"
                if is_bn else
                "Unable to calculate distance. Please specify known origin and destination districts (e.g., 'fare from Dhaka to Gazipur')."
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
        distance_km = straight_dist * FARE_ROAD_FACTOR

    road_dist = round(distance_km, 1)

    # Detect city group
    city_group = detect_city_group(place_from, place_to, lat1, lon1)

    # Query DB rates or use fallback
    rates_dict = {}
    try:
        from assistant.models import VehicleFareRate
        db_rates = VehicleFareRate.objects.filter(city_group=city_group, is_active=True)
        for r in db_rates:
            rates_dict[r.vehicle_type] = {
                'min_base': float(r.base_fare_min),
                'max_base': float(r.base_fare_max),
                'min_km': float(r.per_km_min),
                'max_km': float(r.per_km_max),
                'speed': float(r.average_speed_kmh),
                'max_dist': float(r.max_distance_km) if r.max_distance_km else None,
                'name_en': r.get_vehicle_type_display(),
                'name_bn': r.vehicle_name_bn or r.get_vehicle_type_display(),
            }
    except Exception:
        rates_dict = {}

    if not rates_dict:
        rates_dict = DEFAULT_VEHICLE_RATES.get(city_group, DEFAULT_VEHICLE_RATES['dhaka'])

    # Compute calculations per vehicle
    vehicles_summary = {}
    for v_type, r_data in rates_dict.items():
        max_d = r_data.get('max_dist')
        if max_d and road_dist > max_d:
            vehicles_summary[v_type] = {
                'available': False,
                'reason_en': f'Distance too far for {r_data["name_en"]} (limit ~{max_d} km)',
                'reason_bn': f'{r_data["name_bn"]}-এর জন্য অতিরিক্ত দূরত্ব (~{max_d} কিমির বেশি)',
                'name_en': r_data['name_en'],
                'name_bn': r_data['name_bn'],
            }
            continue

        min_fare = int(math.ceil(max(r_data['min_base'], road_dist * r_data['min_km'])))
        max_fare = int(math.ceil(max(r_data['max_base'], road_dist * r_data['max_km'])))
        speed = max(r_data.get('speed', 20), 5)
        est_minutes = int(math.ceil((road_dist / speed) * 60))

        vehicles_summary[v_type] = {
            'available': True,
            'min_fare': min_fare,
            'max_fare': max_fare,
            'est_minutes': est_minutes,
            'fare_str': f"৳{min_fare} - ৳{max_fare}",
            'name_en': r_data['name_en'],
            'name_bn': r_data['name_bn'],
        }

    # Primary / standard benchmark: CNG / Auto
    cng_data = vehicles_summary.get('cng', {})
    if cng_data.get('available'):
        primary_min = cng_data['min_fare']
        primary_max = cng_data['max_fare']
    else:
        primary_min = int(math.ceil(max(FARE_MIN_BASE_FARE, road_dist * FARE_MIN_RATE_PER_KM)))
        primary_max = int(math.ceil(max(FARE_MAX_BASE_FARE, road_dist * FARE_MAX_RATE_PER_KM)))

    disclaimer_bn = (
        "সকল ভাড়া আনুমানিক হিসাব (পর্যালোচনার জন্য খসড়া হার)। "
        "সময়, আবহাওয়া, রাতের ট্রিপ (রাত ১০টা–সকাল ৬টা) এবং যানজটের কারণে ভাড়া ২৫%–৪০% বাড়তে পারে।"
    )
    disclaimer_en = (
        "Approximate. Real fares vary by time, weather and vehicle. "
        "Night trips (10 PM–6 AM), bad weather, and traffic congestion may increase fares by 25%–40%."
    )

    # Check vehicle mention in user query
    q_lower = query_text.lower()
    highlight_v = None
    if any(k in q_lower for k in ['ambulance', 'অ্যাম্বুলেন্স']):
        highlight_v = 'ambulance'
    elif any(k in q_lower for k in ['rickshaw', 'রিকশা', 'ইজিবাইক']):
        highlight_v = 'rickshaw'
    elif any(k in q_lower for k in ['bike', 'বাইক', 'মোটরসাইকেল']):
        highlight_v = 'bike'
    elif any(k in q_lower for k in ['bus', 'বাস']):
        highlight_v = 'bus'
    elif any(k in q_lower for k in ['car', 'গাড়ি', 'ক্যাব', 'ট্যাক্সি']):
        highlight_v = 'car'

    # Build formatted text response
    if is_bn:
        lines = [
            f"আনুমানিক দূরত্ব: প্রায় {road_dist} কিমি (সড়ক পথ)।",
            f"ভাড়ার সম্ভাব্য পরিসীমা: ৳{primary_min} - ৳{primary_max} (সিএনজি / অটো রেট)।",
            "",
            "যানবাহনভিত্তিক আনুমানিক ভাড়া ও সময়:",
        ]
        order = ['cng', 'rickshaw', 'bike', 'bus', 'car', 'ambulance']
        if highlight_v and highlight_v in order:
            order.remove(highlight_v)
            order.insert(0, highlight_v)

        for vt in order:
            v_info = vehicles_summary.get(vt)
            if not v_info:
                continue
            if v_info.get('available'):
                lines.append(f"• {v_info['name_bn']}: {v_info['fare_str']} (আনুমানিক {v_info['est_minutes']} মিনিট)")
            else:
                lines.append(f"• {v_info['name_bn']}: {v_info['reason_bn']}")

        lines.append("")
        lines.append(f"সতর্কতা: {disclaimer_bn}")
        reply = "\n".join(lines)
    else:
        lines = [
            f"Estimated road distance: approx {road_dist} km.",
            f"Estimated fare range: ৳{primary_min} - ৳{primary_max} (approx local CNG/auto rate).",
            "",
            "Vehicle Fare & Travel Time Estimates:",
        ]
        order = ['cng', 'rickshaw', 'bike', 'bus', 'car', 'ambulance']
        if highlight_v and highlight_v in order:
            order.remove(highlight_v)
            order.insert(0, highlight_v)

        for vt in order:
            v_info = vehicles_summary.get(vt)
            if not v_info:
                continue
            if v_info.get('available'):
                lines.append(f"• {v_info['name_en']}: {v_info['fare_str']} (approx {v_info['est_minutes']} mins)")
            else:
                lines.append(f"• {v_info['name_en']}: {v_info['reason_en']}")

        lines.append("")
        lines.append(f"Notice: {disclaimer_en}")
        reply = "\n".join(lines)

    return {
        "reply": reply,
        "response": reply,
        "source": "fare_estimator",
        "confidence": 1.0,
        "language": "bn" if is_bn else "en",
        "emergency": False,
        "distance_km": road_dist,
        "fare_range": f"{primary_min}-{primary_max} BDT",
        "min_fare_bdt": primary_min,
        "max_fare_bdt": primary_max,
        "city_group": city_group,
        "vehicles": vehicles_summary,
        "is_estimate": True,
        "is_placeholder": True,
        "disclaimer": disclaimer_en,
        "actions": [],
        "flags": ["FARE_ESTIMATE_RANGE"]
    }


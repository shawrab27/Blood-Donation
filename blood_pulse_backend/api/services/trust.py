# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Trust Scoring & Verification Service.
Evaluates request authenticity, calculates trust scores (0-100),
assigns trust bands (LOW, MEDIUM, HIGH), and determines effective scope.
"""

import os
import logging
from api.conf import (
    TRUST_SCORE_BASE,
    TRUST_SCORE_HOSPITAL_VERIFIED,
    TRUST_SCORE_HOSPITAL_UNVERIFIED,
    TRUST_SCORE_PRESCRIPTION_SLIP,
    TRUST_SCORE_PATIENT_PHOTO,
    TRUST_SCORE_ATTENDANT_INFO,
    TRUST_SCORE_DONOR_FULFILLED_BONUS,
    TRUST_SCORE_NO_SHOW_PENALTY,
    TRUST_BAND_LOW_THRESHOLD,
    TRUST_BAND_HIGH_THRESHOLD,
    SCOPE_PERMITTED_BY_TRUST,
)

logger = logging.getLogger(__name__)


def calculate_trust_score(
    hospital=None,
    hospital_name_other: str = '',
    has_requisition_slip: bool = False,
    has_patient_photo: bool = False,
    attendant_name: str = '',
    contact_phone: str = '',
    requester=None,
) -> tuple:
    """
    Computes rule-based trust score (0-100) and corresponding trust band ('LOW', 'MEDIUM', 'HIGH').
    Returns (score: int, band: str).
    """
    from api.models import TrustScoreConfig
    config = TrustScoreConfig.get_solo()
    score = config.base_score

    # Hospital verification bonus
    if hospital and getattr(hospital, 'is_verified', False):
        score += config.hospital_verified
    elif hospital or (hospital_name_other and len(hospital_name_other.strip()) > 3):
        score += TRUST_SCORE_HOSPITAL_UNVERIFIED

    # Requisition slip bonus
    if has_requisition_slip:
        score += config.prescription_slip

    # Patient photo bonus
    if has_patient_photo:
        score += TRUST_SCORE_PATIENT_PHOTO

    # Attendant contact info bonus
    if attendant_name and contact_phone and len(contact_phone.strip()) >= 11:
        score += TRUST_SCORE_ATTENDANT_INFO

    # Requester history bonus / penalty
    if requester and hasattr(requester, 'donorprofile'):
        profile = requester.donorprofile
        fulfilled = getattr(profile, 'fulfilled_count', 0)
        no_shows = getattr(profile, 'no_show_count', 0)

        score += min(15, fulfilled * TRUST_SCORE_DONOR_FULFILLED_BONUS)
        score -= (no_shows * config.no_show_penalty)

    # Clamp score to [0, 100]
    score = max(0, min(100, score))

    if score < TRUST_BAND_LOW_THRESHOLD:
        band = 'LOW'
    elif score < TRUST_BAND_HIGH_THRESHOLD:
        band = 'MEDIUM'
    else:
        band = 'HIGH'

    return score, band


def resolve_effective_scope(requested_scope: str, trust_band: str) -> str:
    """
    Ceils requested scope according to the evaluated trust band to prevent
    unverified broadcasts across divisions or nationwide.
    """
    norm_scope = (requested_scope or 'LOCAL').upper()
    allowed_scopes = SCOPE_PERMITTED_BY_TRUST.get(trust_band, ['LOCAL'])

    if norm_scope in allowed_scopes:
        return norm_scope

    # Fallback to the widest allowed scope in the band
    return allowed_scopes[-1]


def verify_slip_with_ai(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
    """
    Optional Gemini AI slip verification with strict 5s timeout and graceful fallback.
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key or not image_bytes:
        return {'verified': None, 'reason': 'Gemini API key not configured or no image provided'}

    try:
        from google import genai
        from google.genai import types
        import concurrent.futures

        client = genai.Client(api_key=api_key)

        def _call_gemini():
            prompt = (
                "You are an emergency medical requisition slip validator. "
                "Inspect this document. Is it a legitimate hospital prescription, "
                "blood requisition slip, or diagnostic note requesting blood transfusion? "
                "Answer ONLY with a JSON object: {\"is_medical\": true/false, \"confidence\": 0.0-1.0}"
            )
            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                    prompt
                ]
            )
            return response.text

        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(_call_gemini)
            result_text = future.result(timeout=5.0)
            return {'verified': True, 'raw_response': result_text}

    except Exception as e:
        logger.warning(f"AI slip verification skipped or timed out: {e}")
        return {'verified': None, 'reason': str(e)}

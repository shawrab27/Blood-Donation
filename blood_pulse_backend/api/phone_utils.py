# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
from typing import Optional, Set

# Bangladeshi Mobile Operators:
# 013 - Grameenphone (Skitto)
# 014 - Banglalink
# 015 - Teletalk
# 016 - Airtel / Robi
# 017 - Grameenphone
# 018 - Robi
# 019 - Banglalink
# Total 11 digits starting with 01[3-9]
BD_MOBILE_REGEX = re.compile(r'^(?:\+?880|0)?(1[3-9]\d{8})$')


def normalize_phone_number(raw_phone: Optional[str]) -> str:
    """
    Normalizes any Bangladeshi mobile phone number into canonical E.164 format:
    +8801XXXXXXXXX (14 characters: '+880' followed by 10 digits starting with 1[3-9]).

    Accepts inputs such as:
      - 01XXXXXXXXX
      - 8801XXXXXXXXX
      - +8801XXXXXXXXX
      - 1XXXXXXXXX
      - Strings with spaces, dashes, or parentheses (e.g. "+880 1601-239046")

    Raises:
        ValueError: if the number is empty or not a valid Bangladeshi mobile number.
    """
    if not raw_phone:
        raise ValueError("Phone number cannot be empty.")

    # Strip whitespace, hyphens, parentheses, and dots
    cleaned = str(raw_phone).strip()
    # Retain leading + if present, strip other non-digit characters
    has_plus = cleaned.startswith('+')
    digits = ''.join(c for c in cleaned if c.isdigit())

    candidate = f"+{digits}" if has_plus else digits
    match = BD_MOBILE_REGEX.match(candidate)
    if not match:
        raise ValueError(
            f"Invalid Bangladeshi mobile phone number format: {mask_phone(raw_phone)}"
        )

    core_10 = match.group(1)
    return f"+880{core_10}"


def is_valid_phone(raw_phone: Optional[str]) -> bool:
    """Returns True if the raw phone can be normalized to a valid BD mobile number."""
    if not raw_phone:
        return False
    try:
        normalize_phone_number(raw_phone)
        return True
    except ValueError:
        return False


def mask_phone(raw_phone: Optional[str]) -> str:
    """
    Masks a phone number for privacy/security logs.
    Never prints full phone numbers. Shows only the last 3 digits.
    Example: '+8801601239046' -> '***...046'
    """
    if not raw_phone:
        return "***"
    digits = ''.join(c for c in str(raw_phone) if c.isdigit())
    if len(digits) >= 3:
        return f"***...{digits[-3:]}"
    return "***"


def get_phone_variants(raw_phone: Optional[str]) -> Set[str]:
    """
    Returns all standard representations of a phone number for tolerant database queries:
      - Canonical: +8801XXXXXXXXX
      - International without plus: 8801XXXXXXXXX
      - Local 11-digit: 01XXXXXXXXX
      - Core 10-digit: 1XXXXXXXXX
    """
    variants: Set[str] = set()
    if not raw_phone:
        return variants

    try:
        canonical = normalize_phone_number(raw_phone)
        core_10 = canonical[-10:]
        variants.add(canonical)
        variants.add(f"880{core_10}")
        variants.add(f"0{core_10}")
        variants.add(core_10)
    except ValueError:
        # Fallback if non-canonical
        digits = ''.join(c for c in str(raw_phone) if c.isdigit())
        if len(digits) >= 10:
            core_10 = digits[-10:]
            variants.add(core_10)
            variants.add(f"0{core_10}")
            variants.add(f"880{core_10}")
            variants.add(f"+880{core_10}")
    return variants

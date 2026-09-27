# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

# To be reviewed by qualified medical staff before real-world use.
"""
Blood Component Compatibility Service.
Implements standard blood bank ABO and Rh compatibility rules for:
- WHOLE: Whole blood transfusion
- RBC: Packed Red Blood Cells
- PLATELETS: Platelet concentrate
- PLASMA: Fresh Frozen Plasma (FFP)
"""

# Red blood cell & whole blood donor compatibility (Recipient -> Compatible Donors)
RBC_COMPATIBILITY_RECIPIENT_MAP = {
    'AB+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
}

# Plasma compatibility (AB is universal plasma donor, O is universal recipient)
PLASMA_COMPATIBILITY_RECIPIENT_MAP = {
    'AB+': ['AB+', 'AB-'],
    'AB-': ['AB+', 'AB-'],
    'A+': ['A+', 'A-', 'AB+', 'AB-'],
    'A-': ['A+', 'A-', 'AB+', 'AB-'],
    'B+': ['B+', 'B-', 'AB+', 'AB-'],
    'B-': ['B+', 'B-', 'AB+', 'AB-'],
    'O+': ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
    'O-': ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
}

# Platelets follow plasma rules closely for ABO matching
PLATELET_COMPATIBILITY_RECIPIENT_MAP = PLASMA_COMPATIBILITY_RECIPIENT_MAP


def normalize_blood_group(group: str) -> str:
    """Normalize blood group representation e.g. 'A_POS' -> 'A+', 'O_NEG' -> 'O-'"""
    if not group:
        return ''
    cleaned = group.strip().upper()
    replacements = {
        'A_POS': 'A+', 'A_NEG': 'A-',
        'B_POS': 'B+', 'B_NEG': 'B-',
        'AB_POS': 'AB+', 'AB_NEG': 'AB-',
        'O_POS': 'O+', 'O_NEG': 'O-',
        'APOS': 'A+', 'ANEG': 'A-',
        'BPOS': 'B+', 'BNEG': 'B-',
        'ABPOS': 'AB+', 'ABNEG': 'AB-',
        'OPOS': 'O+', 'ONEG': 'O-',
    }
    return replacements.get(cleaned, cleaned)


def get_compatible_donor_groups(recipient_group: str, component: str = 'WHOLE') -> list:
    """
    Returns list of donor blood groups compatible with the given recipient blood group
    and component type.
    """
    norm_recipient = normalize_blood_group(recipient_group)
    norm_component = (component or 'WHOLE').strip().upper()

    if norm_component in ('WHOLE', 'RBC'):
        return RBC_COMPATIBILITY_RECIPIENT_MAP.get(norm_recipient, [norm_recipient])
    elif norm_component == 'PLASMA':
        return PLASMA_COMPATIBILITY_RECIPIENT_MAP.get(norm_recipient, [norm_recipient])
    elif norm_component == 'PLATELETS':
        return PLATELET_COMPATIBILITY_RECIPIENT_MAP.get(norm_recipient, [norm_recipient])
    
    return RBC_COMPATIBILITY_RECIPIENT_MAP.get(norm_recipient, [norm_recipient])


def is_compatible(donor_group: str, recipient_group: str, component: str = 'WHOLE') -> bool:
    """Check if donor group can safely donate to recipient group."""
    norm_donor = normalize_blood_group(donor_group)
    compatible_groups = get_compatible_donor_groups(recipient_group, component)
    return norm_donor in compatible_groups

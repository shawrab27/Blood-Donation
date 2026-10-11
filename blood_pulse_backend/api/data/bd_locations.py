"""
Bangladesh Administrative Divisions and Districts (Canonical Dataset).
Single source of truth for Bangladesh 8 divisions and 64 districts.
Aligned with BloodPulse Flutter client bundled map in registration_screen.dart and communities_view.dart.
Counts:
- Dhaka: 13
- Chattogram: 11
- Rajshahi: 8
- Khulna: 10
- Barishal: 6
- Sylhet: 4
- Rangpur: 8
- Mymensingh: 4
Total: 64 districts across 8 divisions.
"""

# Canonical structure: division_name -> list of canonical district names
BD_DIVISIONS_AND_DISTRICTS = {
    'Dhaka': [
        'Dhaka', 'Faridpur', 'Gazipur', 'Gopalganj', 'Kishoreganj',
        'Madaripur', 'Manikganj', 'Munshiganj', 'Narayanganj', 'Narsingdi',
        'Rajbari', 'Shariatpur', 'Tangail'
    ],
    'Chattogram': [
        'Bandarban', 'Brahmanbaria', 'Chandpur', 'Chattogram', "Cox's Bazar",
        'Cumilla', 'Feni', 'Khagrachhari', 'Lakshmipur', 'Noakhali',
        'Rangamati'
    ],
    'Rajshahi': [
        'Bogura', 'Chapai Nawabganj', 'Joypurhat', 'Naogaon', 'Natore',
        'Pabna', 'Rajshahi', 'Sirajganj'
    ],
    'Khulna': [
        'Bagerhat', 'Chuadanga', 'Jashore', 'Jhenaidah', 'Khulna',
        'Kushtia', 'Magura', 'Meherpur', 'Narail', 'Satkhira'
    ],
    'Barishal': [
        'Barguna', 'Barishal', 'Bhola', 'Jhalokati', 'Patuakhali',
        'Pirojpur'
    ],
    'Sylhet': [
        'Habiganj', 'Moulvibazar', 'Sunamganj', 'Sylhet'
    ],
    'Rangpur': [
        'Dinajpur', 'Gaibandha', 'Kurigram', 'Lalmonirhat', 'Nilphamari',
        'Panchagarh', 'Rangpur', 'Thakurgaon'
    ],
    'Mymensingh': [
        'Jamalpur', 'Mymensingh', 'Netrokona', 'Sherpur'
    ],
}

# Known alternate spellings / aliases mapped to canonical name
DISTRICT_ALIASES = {
    'Chapainawabganj': 'Chapai Nawabganj',
    'Chittagong': 'Chattogram',
    'Comilla': 'Cumilla',
    'Barisal': 'Barishal',
    'Jessore': 'Jashore',
    'Bogra': 'Bogura',
    'Jhalokathi': 'Jhalokati',
    'Coxs Bazar': "Cox's Bazar",
    'Coxsbazar': "Cox's Bazar",
    'Moulvi Bazar': 'Moulvibazar',
    'Netrakona': 'Netrokona',
}

DIVISION_ALIASES = {
    'Chittagong': 'Chattogram',
    'Barisal': 'Barishal',
}

EXPECTED_DIVISION_COUNTS = {
    'Dhaka': 13,
    'Chattogram': 11,
    'Rajshahi': 8,
    'Khulna': 10,
    'Barishal': 6,
    'Sylhet': 4,
    'Rangpur': 8,
    'Mymensingh': 4,
}

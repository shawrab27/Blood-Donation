# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_pulse_backend.settings')
django.setup()

from api.models import HealthAccessory

items = [
    {
      'title': 'Digital Blood Pressure (BP) Monitor (Arm/Wrist)',
      'category': 'Diagnostic & Clinic',
      'description': 'Certified oscillometric upper arm cuff with irregular heartbeat detection, dual-user memory, and high-contrast LCD readout.',
      'priceRange': '৳2,200 - ৳3,800',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=digital+blood+pressure+monitor',
      'storeName': '', 
    },
    {
      'title': 'Fingertip Pulse Oximeter (SpO2 & Pulse Tracker)',
      'category': 'Diagnostic & Clinic',
      'description': 'Medical-grade photoelectric sensor measuring SpO2 arterial oxygen saturation and PR blood pulse rate in under 5 seconds.',
      'priceRange': '৳850 - ৳1,500',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=pulse+oximeter',
      'storeName': '',
    },
    {
      'title': 'Blood Glucose Test Strips & Lancets (Pack of 50-100)',
      'category': 'Consumables',
      'description': 'Ultra-thin gold electrode strips requiring minimal capillary sample (0.5µL) for fast, painless blood chemistry testing.',
      'priceRange': '৳650 - ৳1,200',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=glucose+test+strips+lancets',
      'storeName': '',
    },
    {
      'title': 'Iron + Folic Acid Donor Recovery Booster',
      'category': 'Consumables',
      'description': 'Chelated ferrous bisglycinate with Vitamin C and methylfolate to restore hemoglobin levels rapidly post-donation without nausea.',
      'priceRange': '৳450 - ৳900',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=iron+folic+acid+supplement',
      'storeName': '',
    },
    {
      'title': 'Quick-Release Phlebotomy Tourniquet Band',
      'category': 'Parts & Kits',
      'description': 'Elastic cotton latex-free band with quick-release buckle designed for gentle venous occlusion during emergency phlebotomy.',
      'priceRange': '৳120 - ৳250',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=phlebotomy+tourniquet',
      'storeName': '',
    },
    {
      'title': 'Adjustable Lancing Device Pen',
      'category': 'Parts & Kits',
      'description': 'Precision depth adjustment dial (1 to 5 levels) minimizing puncture pain for regular capillary blood sampling and hemoglobin checks.',
      'priceRange': '৳250 - ৳450',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=lancing+pen+device',
      'storeName': '',
    },
    {
      'title': 'Replacement Arm Cuffs & Bladders for BP Machines',
      'category': 'Parts & Kits',
      'description': 'Universal 22-48cm extra-wide nylon cuff compatible with all standard digital and aneroid blood pressure monitoring units.',
      'priceRange': '৳450 - ৳850',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=blood+pressure+monitor+cuff',
      'storeName': '',
    },
    {
      'title': 'Blood Group / Voluntary Donor Silicone Wristband',
      'category': 'Donor Gear',
      'description': 'Hypoallergenic debossed silicone identification bracelet displaying blood type (A+, B+, O+, AB-) for emergency responder awareness.',
      'priceRange': '৳80 - ৳150',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=blood+group+wristband',
      'storeName': '',
    },
    {
      'title': 'Red Drop Enamel Donor Pin & Badge Reel',
      'category': 'Donor Gear',
      'description': 'Gold-plated zinc alloy enamel badge with "Be A Lifesaver" insignia for regular donors, volunteers, and medical staff.',
      'priceRange': '৳150 - ৳300',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=blood+donor+pin+badge',
      'storeName': '',
    },
    {
      'title': 'Compact Hemostatic Emergency First Aid Kit',
      'category': 'Consumables',
      'description': 'Travel-ready medical pouch containing coagulant gauze, antiseptic wipes, sterile dressings, and CPR face shield for trauma response.',
      'priceRange': '৳750 - ৳1,600',
      'affiliateUrl': 'https://www.daraz.com.bd/catalog/?q=emergency+first+aid+kit',
      'storeName': '',
    }
]

HealthAccessory.objects.all().delete()
for idx, i in enumerate(items):
    HealthAccessory.objects.create(
        name_en=i['title'],
        category=i['category'],
        description_en=i['description'],
        affiliate_url=i['affiliateUrl'],
        store_name=i['storeName'],
        price_range_text=i['priceRange'],
        display_order=idx
    )
print('Successfully seeded health accessories')

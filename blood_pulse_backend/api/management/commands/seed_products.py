# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from api.models import Product, ProductImage


def is_production_db():
    db_settings = settings.DATABASES.get('default', {})
    db_host = str(db_settings.get('HOST', ''))
    django_env = (os.environ.get('DJANGO_ENV') or getattr(settings, 'DJANGO_ENV', '')).strip().lower()

    if 'neon.tech' in db_host or 'ep-noisy-poetry' in db_host:
        return True
    if django_env in ('prod', 'production'):
        return True
    return False


DEMO_PRODUCTS = [
    # Tier 1 - Diagnostic & Clinic
    {
        'name': 'Digital Blood Pressure Monitor (Omron HEM-7120)',
        'tier': 1,
        'description': 'Clinically validated upper-arm digital BP monitor for pre-donation vital screenings. High accuracy oscillation technology with pulse rate indicator.',
        'price_min': 2450.00,
        'price_max': 2750.00,
        'currency': 'BDT',
        'store_name': 'Lazz Pharma',
        'external_url': 'https://www.lazzpharma.com',
        'availability_text': 'Available in Stock',
        'is_featured': True,
        'sort_order': 1,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },
    {
        'name': 'Fingertip Pulse Oximeter (Contec CMS50D)',
        'tier': 1,
        'description': 'Portable blood oxygen saturation SpO2 and pulse monitor. Clear OLED display with rapid reading for donor readiness verification.',
        'price_min': 950.00,
        'price_max': 1250.00,
        'currency': 'BDT',
        'store_name': 'Arogga',
        'external_url': 'https://www.arogga.com',
        'availability_text': 'Available Online',
        'is_featured': True,
        'sort_order': 2,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },

    # Tier 2 - Consumables
    {
        'name': 'Accu-Chek Active Glucose Test Strips (50 Pcs)',
        'tier': 2,
        'description': 'Blood glucose test strips for pre-donation glycemic suitability checks. Requires minimal blood volume with 5-second rapid testing.',
        'price_min': 1150.00,
        'price_max': 1350.00,
        'currency': 'BDT',
        'store_name': 'Osdhimart',
        'external_url': 'https://www.oshidmart.com',
        'availability_text': 'In Stock',
        'is_featured': False,
        'sort_order': 3,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },
    {
        'name': 'Sterile Twist Blood Lancets 30G (100 Pcs)',
        'tier': 2,
        'description': 'Ultra-fine capillary blood sampling sterile lancets for hemoglobin and blood typing screenings with minimal discomfort.',
        'price_min': 220.00,
        'price_max': 280.00,
        'currency': 'BDT',
        'store_name': 'Chaldal Health',
        'external_url': 'https://chaldal.com',
        'availability_text': 'In Stock',
        'is_featured': False,
        'sort_order': 4,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },

    # Tier 3 - Parts & Kits
    {
        'name': 'Adjustable Arm Cuff for Digital BP Monitor (Standard 22-32cm)',
        'tier': 3,
        'description': 'Durable replacement nylon cuff compatible with major automatic sphygmomanometers. Double-stitched with standard connector.',
        'price_min': 450.00,
        'price_max': 600.00,
        'currency': 'BDT',
        'store_name': 'Daraz Mall',
        'external_url': 'https://www.daraz.com.bd',
        'availability_text': 'Available Online',
        'is_featured': False,
        'sort_order': 5,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1584017911766-d451b3d0e843?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },
    {
        'name': 'Dual Head Clinical Diagnostic Stethoscope',
        'tier': 3,
        'description': 'Acoustic stethoscope with high-sensitivity chestpiece for accurate heart-sound screening before phlebotomy.',
        'price_min': 1250.00,
        'price_max': 1650.00,
        'currency': 'BDT',
        'store_name': 'Beximco Health',
        'external_url': 'https://www.beximco.com',
        'availability_text': 'Available Online',
        'is_featured': False,
        'sort_order': 6,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },

    # Tier 4 - Donor Gear
    {
        'name': 'BloodPulse Hero Donor Silicone Wristband (Red/White)',
        'tier': 4,
        'description': 'Debossed medical-grade hypoallergenic silicone wristband celebrating everyday life-saving blood donors across Bangladesh.',
        'price_min': 80.00,
        'price_max': 120.00,
        'currency': 'BDT',
        'store_name': 'BloodPulse Community Gear',
        'external_url': 'https://bloodpulse.org/gear',
        'availability_text': 'In Stock',
        'is_featured': True,
        'sort_order': 7,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },
    {
        'name': 'Gold Hero Blood Donor Lapel Pin',
        'tier': 4,
        'description': 'Enameled metallic lapel pin honoring voluntary blood donation milestones. Polished finish with secure butterfly clutch.',
        'price_min': 150.00,
        'price_max': 200.00,
        'currency': 'BDT',
        'store_name': 'BloodPulse Community Gear',
        'external_url': 'https://bloodpulse.org/gear',
        'availability_text': 'Limited Stock',
        'is_featured': False,
        'sort_order': 8,
        'images': [
            {'url': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=600&q=80', 'order': 1},
        ],
    },
]


class Command(BaseCommand):
    help = "Seeds 8 demo clinical & blood accessories across Tiers 1-4 with is_demo=True. Refuses production."

    def add_arguments(self, parser):
        parser.add_argument(
            '--i-understand-this-creates-demo-data',
            action='store_true',
            dest='confirmed',
            help='Confirmation flag to allow seeding demo products.',
        )

    def handle(self, *args, **options):
        if is_production_db():
            raise CommandError("SAFETY BLOCK: Refusing to seed demo products against production Neon database!")

        if not options.get('confirmed'):
            raise CommandError("Refusing to seed demo data without '--i-understand-this-creates-demo-data' confirmation.")

        created_count = 0
        for raw_data in DEMO_PRODUCTS:
            data = dict(raw_data)
            images = data.pop('images', [])
            product, created = Product.objects.update_or_create(
                name=data['name'],
                defaults={
                    **data,
                    'is_demo': True,
                    'is_active': True,
                }
            )
            if created:
                created_count += 1

            for img_info in images:
                ProductImage.objects.get_or_create(
                    product=product,
                    image_url=img_info['url'],
                    defaults={
                        'display_order': img_info['order'],
                        'public_id': f"demo_product_{product.id}_{img_info['order']}",
                    }
                )

        self.stdout.write(self.style.SUCCESS(f"Successfully seeded {len(DEMO_PRODUCTS)} demo products across Tiers 1-4."))

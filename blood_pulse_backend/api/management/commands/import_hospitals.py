"""
Management command to import authentic hospitals from CSV or seed authentic referral centers.
Usage:
  python manage.py import_hospitals --csv /path/to/hospitals.csv
  python manage.py import_hospitals --seed-major
"""

import csv
import os
from django.core.management.base import BaseCommand
from api.models import Hospital, Division, District


MAJOR_BANGLADESH_HOSPITALS = [
    {
        'name': 'Dhaka Medical College Hospital',
        'name_en': 'Dhaka Medical College Hospital',
        'name_bn': 'ঢাকা মেডিকেল কলেজ হাসপাতাল',
        'district': 'Dhaka',
        'address': 'Secretariat Rd, Dhaka 1000',
        'lat': 23.7259,
        'lng': 90.3976,
        'phone': '+880255165088',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Bangabandhu Sheikh Mujib Medical University (BSMMU)',
        'name_en': 'Bangabandhu Sheikh Mujib Medical University',
        'name_bn': 'বঙ্গবন্ধু শেখ মুজিব মেডিকেল বিশ্ববিদ্যালয়',
        'district': 'Dhaka',
        'address': 'Shahbag, Dhaka 1000',
        'lat': 23.7388,
        'lng': 90.3957,
        'phone': '+88029661051',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'National Institute of Cardiovascular Diseases (NICVD)',
        'name_en': 'National Institute of Cardiovascular Diseases',
        'name_bn': 'জাতীয় হৃদরোগ ইনস্টিটিউট ও হাসপাতাল',
        'district': 'Dhaka',
        'address': 'Sher-e-Bangla Nagar, Dhaka 1207',
        'lat': 23.7712,
        'lng': 90.3693,
        'phone': '+88029122560',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Chittagong Medical College Hospital',
        'name_en': 'Chittagong Medical College Hospital',
        'name_bn': 'চট্টগ্রাম মেডিকেল কলেজ হাসপাতাল',
        'district': 'Chattogram',
        'address': '57 K.B. Fazlul Kader Rd, Chattogram 4203',
        'lat': 22.3598,
        'lng': 91.8286,
        'phone': '+88031616382',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Rajshahi Medical College Hospital',
        'name_en': 'Rajshahi Medical College Hospital',
        'name_bn': 'রাজশাহী মেডিকেল কলেজ হাসপাতাল',
        'district': 'Rajshahi',
        'address': 'Medical College Rd, Rajshahi 6000',
        'lat': 24.3707,
        'lng': 88.5833,
        'phone': '+880721772150',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Sylhet MAG Osmani Medical College Hospital',
        'name_en': 'Sylhet MAG Osmani Medical College Hospital',
        'name_bn': 'সিলেট এম এ জি ওসমানী মেডিকেল কলেজ হাসপাতাল',
        'district': 'Sylhet',
        'address': 'Medical College Rd, Kajalshah, Sylhet 3100',
        'lat': 24.8988,
        'lng': 91.8542,
        'phone': '+880821713487',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Khulna Medical College Hospital',
        'name_en': 'Khulna Medical College Hospital',
        'name_bn': 'খুলনা মেডিকেল কলেজ হাসপাতাল',
        'district': 'Khulna',
        'address': 'Boyra Main Rd, Khulna 9000',
        'lat': 22.8456,
        'lng': 89.5403,
        'phone': '+88041761509',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Sher-e-Bangla Medical College Hospital',
        'name_en': 'Sher-e-Bangla Medical College Hospital',
        'name_bn': 'শের-ই-বাংলা মেডিকেল কলেজ হাসপাতাল',
        'district': 'Barishal',
        'address': 'Hospital Road, Barishal 8200',
        'lat': 22.6908,
        'lng': 90.3582,
        'phone': '+8804312173541',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Rangpur Medical College Hospital',
        'name_en': 'Rangpur Medical College Hospital',
        'name_bn': 'রংপুর মেডিকেল কলেজ হাসপাতাল',
        'district': 'Rangpur',
        'address': 'Medical Purba Gate Rd, Rangpur 5400',
        'lat': 25.7533,
        'lng': 89.2317,
        'phone': '+88052163351',
        'is_verified': True,
        'is_referral_center': True,
    },
    {
        'name': 'Mymensingh Medical College Hospital',
        'name_en': 'Mymensingh Medical College Hospital',
        'name_bn': 'ময়মনসিংহ মেডিকেল কলেজ হাসপাতাল',
        'district': 'Mymensingh',
        'address': 'Char Para, Mymensingh 2200',
        'lat': 24.7397,
        'lng': 90.4125,
        'phone': '+8809166063',
        'is_verified': True,
        'is_referral_center': True,
    },
]


class Command(BaseCommand):
    help = "Import authentic hospitals from a CSV file or seed authentic referral centers."

    def add_arguments(self, parser):
        parser.add_argument('--csv', type=str, help='Path to CSV file with hospital records.')
        parser.add_argument('--seed-major', action='store_true', help='Seed authentic major referral hospitals.')

    def handle(self, *args, **options):
        csv_path = options.get('csv')
        seed_major = options.get('seed_major')

        if seed_major or not csv_path:
            self.stdout.write(self.style.NOTICE("Importing authentic major referral hospitals in Bangladesh..."))
            created_count = 0
            for item in MAJOR_BANGLADESH_HOSPITALS:
                hospital, created = Hospital.objects.get_or_create(
                    name=item['name'],
                    district=item['district'],
                    defaults={
                        'name_en': item['name_en'],
                        'name_bn': item['name_bn'],
                        'address': item['address'],
                        'lat': item['lat'],
                        'lng': item['lng'],
                        'phone': item['phone'],
                        'is_verified': item['is_verified'],
                        'is_referral_center': item['is_referral_center'],
                    }
                )
                if created:
                    created_count += 1
            self.stdout.write(self.style.SUCCESS(f"Successfully processed {len(MAJOR_BANGLADESH_HOSPITALS)} hospitals ({created_count} new created)."))

        if csv_path:
            if not os.path.exists(csv_path):
                self.stderr.write(self.style.ERROR(f"File not found: {csv_path}"))
                return

            self.stdout.write(f"Importing from CSV: {csv_path}...")
            count = 0
            with open(csv_path, mode='r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    name = row.get('name', '').strip()
                    district = row.get('district', '').strip()
                    if not name or not district:
                        continue

                    Hospital.objects.update_or_create(
                        name=name,
                        district=district,
                        defaults={
                            'name_en': row.get('name_en', name),
                            'name_bn': row.get('name_bn', ''),
                            'address': row.get('address', ''),
                            'lat': float(row['lat']) if row.get('lat') else None,
                            'lng': float(row['lng']) if row.get('lng') else None,
                            'phone': row.get('phone', ''),
                            'is_verified': row.get('is_verified', 'true').lower() in ('true', '1'),
                            'is_referral_center': row.get('is_referral_center', 'false').lower() in ('true', '1'),
                        }
                    )
                    count += 1
            self.stdout.write(self.style.SUCCESS(f"Successfully imported {count} hospitals from CSV."))

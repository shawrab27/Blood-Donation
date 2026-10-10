# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from api.models import (
    DonorProfile, Hospital, NationalEmergencyEvent, 
    DisasterResponsePoint, DonationSlot, Division, District, Upazila
)
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
import datetime

import os
import secrets

User = get_user_model()

class Command(BaseCommand):
    help = 'Seeds BloodHub with demo data for end-to-end testing.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--i-understand-this-creates-fake-users',
            action='store_true',
            dest='confirm_fake_users',
            help='Explicit acknowledgment that fake users will be created in the database.',
        )

    def handle(self, *args, **options):
        django_env = os.environ.get('DJANGO_ENV', '').strip().lower()
        if django_env not in ('dev', 'test'):
            self.stdout.write(self.style.ERROR(
                f"Refusing to seed demo data when DJANGO_ENV is '{django_env}'. Must be 'dev' or 'test'."
            ))
            return

        if not options.get('confirm_fake_users'):
            self.stdout.write(self.style.ERROR(
                "Refusing to seed demo data. You must pass '--i-understand-this-creates-fake-users' flag."
            ))
            return

        # Generate a random password printed once
        generated_password = secrets.token_urlsafe(16)
        self.stdout.write(self.style.WARNING(
            f"Generated one-time demo password for seeded users: {generated_password}"
        ))

        self.stdout.write(self.style.WARNING("Starting demo data seed..."))

        # Clean up old data
        User.objects.filter(username__startswith='demo_').delete()
        DonorProfile.objects.filter(phone_number__in=["01700000001", "01700000002", "01700000003"]).delete()
        NationalEmergencyEvent.objects.filter(title_en__contains="DRILL").delete()

        division, _ = Division.objects.get_or_create(name="Dhaka")
        district, _ = District.objects.get_or_create(name="Dhaka", division=division)
        upazila, _ = Upazila.objects.get_or_create(name="Shahbag", district=district)

        # Create Hospital
        hosp, created = Hospital.objects.update_or_create(
            name="Dhaka Medical College Hospital (DEMO)",
            defaults={
                'name_en': 'Dhaka Medical College Hospital (DEMO)',
                'address': "Secretariat Road, Dhaka 1000",
                'lat': 23.7258,
                'lng': 90.3957,
                'division': division,
                'district': "Dhaka",
                'upazila': upazila,
            }
        )
        self.stdout.write(self.style.SUCCESS(f"Hospital ready: {hosp.name}"))

        # Create Demo Donors matching Stitch UI specifications
        demo_donors = [
            ("zahir.raihan@bloodpulse.com", "Zahir", "Raihan", "01700000001", "A+", "Dhaka Medical College", "Dhaka", 23.7258, 90.3957, 120),
            ("anika.tabassum@bloodpulse.com", "Anika", "Tabassum", "01700000002", "O-", "BUET Campus", "Dhaka", 23.7266, 90.3898, 180),
            ("samiul.islam@bloodpulse.com", "Samiul", "Islam", "01700000003", "B+", "Mirpur, Dhaka", "Dhaka", 23.8050, 90.3680, 365),
            ("tanvir.hossain@bloodpulse.com", "Tanvir", "Hossain", "01700000004", "AB+", "Dhaka University", "Dhaka", 23.7335, 90.3928, 60),
            ("nusrat.jahan@bloodpulse.com", "Nusrat", "Jahan", "01700000005", "A-", "North South University", "Dhaka", 23.8151, 90.4255, 150),
            ("farhan.ahmed@bloodpulse.com", "Farhan", "Ahmed", "01700000006", "O+", "Dhaka Medical College", "Dhaka", 23.7270, 90.3970, 90),
            ("sadia.rahman@bloodpulse.com", "Sadia", "Rahman", "01700000007", "B-", "Gazipur Campus", "Gazipur", 23.9535, 90.3833, 210),
            ("mahmudul.hasan@bloodpulse.com", "Mahmudul", "Hasan", "01700000008", "AB-", "Chittagong Medical College", "Chattogram", 22.3587, 91.8215, 120),
        ]

        now = timezone.now()
        for email, first, last, phone, bg, campus_name, dist_name, lat, lng, days_ago in demo_donors:
            user, u_created = User.objects.get_or_create(
                username=email,
                defaults={
                    'email': email,
                    'first_name': first,
                    'last_name': last,
                    'is_staff': False,
                    'is_superuser': False,
                }
            )
            if u_created:
                user.set_password(generated_password)
                user.save()
            else:
                user.first_name = first
                user.last_name = last
                user.save()

            
            profile, p_created = DonorProfile.objects.update_or_create(
                user=user,
                defaults={
                    'phone_number': phone,
                    'blood_group': bg,
                    'campus': campus_name,
                    'district': dist_name,
                    'address': f"{campus_name}, {dist_name}",
                    'latitude': lat,
                    'longitude': lng,
                    'last_lat': lat,
                    'last_lng': lng,
                    'is_available': True,
                    'is_searchable': True,
                    'is_verified': True,
                    'email_verified': True,
                    'is_profile_complete': True,
                    'last_donation_date': (now - timedelta(days=days_ago)).date(),
                    'total_bags_donated': max(1, days_ago // 100),
                }
            )
            self.stdout.write(self.style.SUCCESS(f"Donor ready: {user.get_full_name()} ({bg}, {campus_name})"))

        # Create a Drill Disaster Event
        now = timezone.now()
        event, e_created = NationalEmergencyEvent.objects.get_or_create(
            title_en="OPERATION LIFELINE (DRILL)",
            defaults={
                'description_en': "This is a system-wide drill to test our emergency response network.",
                'is_active': True,
                'is_verified': True,
                'started_at': now - timedelta(hours=2),
                'ended_at': now + timedelta(days=2)
            }
        )
        self.stdout.write(self.style.SUCCESS(f"Event ready: {event.title_en}"))

        # Create Response Points for the Event
        point, pt_created = DisasterResponsePoint.objects.get_or_create(
            event=event,
            name=hosp.name,
            defaults={
                'lat': hosp.lat, 
                'lng': hosp.lng, 
                'district': hosp.district,
                'target_bags': 100, 
                'collected_bags': 0,
                'status': 'ACTIVE',
            }
        )
        self.stdout.write(self.style.SUCCESS(f"Response Point ready: {point.name}"))

        # Create Slots for the Response Point
        time_ranges = ["09:00 AM - 11:00 AM", "11:00 AM - 01:00 PM", "02:00 PM - 04:00 PM"]
        for tr in time_ranges:
            DonationSlot.objects.get_or_create(
                point=point,
                time_range=tr,
                defaults={
                    'capacity': 10,
                    'pledged': 0
                }
            )
        self.stdout.write(self.style.SUCCESS(f"Slots created!"))

        self.stdout.write(self.style.SUCCESS("Demo data seed complete!"))

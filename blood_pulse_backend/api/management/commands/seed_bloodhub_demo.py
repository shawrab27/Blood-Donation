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

User = get_user_model()

class Command(BaseCommand):
    help = 'Seeds BloodHub with demo data for end-to-end testing.'

    def handle(self, *args, **options):
        if not settings.DEBUG:
            self.stdout.write(self.style.ERROR("Refusing to seed demo data when DEBUG is False."))
            return

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

        # Create Demo Donors
        emails = [
            ("demo_donor1@bloodpulse.com", "Demo Donor 1", "01700000001", "A+"),
            ("demo_donor2@bloodpulse.com", "Demo Donor 2", "01700000002", "O-"),
            ("demo_admin@bloodpulse.com", "Demo Admin", "01700000003", "B+"),
        ]

        for email, name, phone, bg in emails:
            user, u_created = User.objects.get_or_create(
                username=email,
                defaults={
                    'email': email,
                    'first_name': name.split()[0],
                    'last_name': name.split()[1],
                    'is_staff': 'admin' in email.lower(),
                    'is_superuser': 'admin' in email.lower(),
                }
            )
            if u_created:
                user.set_password('demo1234')
                user.save()
            
            profile, p_created = DonorProfile.objects.update_or_create(
                user=user,
                defaults={
                    'phone_number': phone,
                    'blood_group': bg,
                    'is_available': True,
                    'is_verified': True,
                    'email_verified': True,
                    'district': "Dhaka",
                    'is_profile_complete': True,
                }
            )
            self.stdout.write(self.style.SUCCESS(f"User ready: {user.email}"))

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

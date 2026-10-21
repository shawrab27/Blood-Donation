# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils import timezone

from api.models import (
    BloodRequest,
    RequestAcceptance,
    DonationMatch,
    DonorProfile,
    RequestTimelineEvent,
    Hospital,
)
from api.services.blood_hub_lifecycle_service import transition
from api.utils.phone import normalize_phone_number


class Command(BaseCommand):
    help = (
        "Staff-only journey demo seeder for two-phone live testing (Part 8).\n"
        "Creates a verified demo journey in a specified state.\n"
        "REFUSES unless ALLOW_TEST_SEED=true in the environment. NEVER run on production."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--requester',
            type=str,
            required=True,
            help='Username, ID, or phone number of existing requester user.',
        )
        parser.add_argument(
            '--donor',
            type=str,
            required=True,
            help='Username, ID, or phone number of existing donor user.',
        )
        parser.add_argument(
            '--state',
            type=str,
            default='ACCEPTED',
            choices=['ACCEPTED', 'DONOR_ON_THE_WAY', 'STANDBY_SEARCHING', 'COMPLETED'],
            help='Initial journey state to seed (default: ACCEPTED).',
        )
        parser.add_argument(
            '--blood-group',
            type=str,
            default='O+',
            help='Blood group requested (default: O+).',
        )

    def _find_user(self, identifier: str):
        identifier = identifier.strip()
        if identifier.isdigit():
            u = User.objects.filter(pk=int(identifier)).first()
            if u:
                return u
        u = User.objects.filter(
            Q(username__iexact=identifier) | Q(email__iexact=identifier)
        ).first()
        if u:
            return u
        # Try phone matching
        norm_phone = normalize_phone_number(identifier)
        donor = DonorProfile.objects.filter(phone_number=norm_phone).select_related('user').first()
        if donor and donor.user:
            return donor.user
        return None

    def handle(self, *args, **options):
        # 1. Safety check
        if os.environ.get('ALLOW_TEST_SEED') != 'true':
            self.stderr.write(self.style.ERROR(
                "ABORTED: seed_journey_demo refused. Environment variable ALLOW_TEST_SEED=true is required."
            ))
            sys.exit(1)

        # 2. Prevent running on production host
        from django.conf import settings
        db_host = settings.DATABASES.get('default', {}).get('HOST', '')
        if 'neon.tech' in db_host or 'aws.neon.tech' in db_host:
            self.stderr.write(self.style.ERROR(
                "ABORTED: seed_journey_demo refused on production database host."
            ))
            sys.exit(1)

        # 3. Resolve requester and donor
        req_id_str = options['requester']
        donor_id_str = options['donor']
        target_state = options['state']
        blood_group = options['blood_group']

        requester = self._find_user(req_id_str)
        if not requester:
            self.stderr.write(self.style.ERROR(f"Requester user '{req_id_str}' not found."))
            sys.exit(1)

        donor_user = self._find_user(donor_id_str)
        if not donor_user:
            self.stderr.write(self.style.ERROR(f"Donor user '{donor_id_str}' not found."))
            sys.exit(1)

        donor_profile = getattr(donor_user, 'donorprofile', None)
        if not donor_profile:
            donor_profile = DonorProfile.objects.filter(user=donor_user).first()
        if not donor_profile:
            self.stderr.write(self.style.ERROR(f"Donor user '{donor_user.username}' has no DonorProfile."))
            sys.exit(1)

        now = timezone.now()

        # 4. Create Demo BloodRequest
        hosp = Hospital.objects.filter(is_partner=True).first()
        req = BloodRequest.objects.create(
            requester=requester,
            patient_name="Demo Patient (Journey Test)",
            blood_group=blood_group,
            urgency_level="CRITICAL_2H",
            hospital_location="Dhaka Medical College Hospital, Emergency Wing",
            hospital=hosp,
            contact_number=requester.username if requester.username.startswith('+880') else "+8801700000001",
            contact_phone=requester.username if requester.username.startswith('+880') else "+8801700000001",
            lat=23.7258,
            lng=90.3976,
            units_needed=1,
            units_received=1 if target_state == 'COMPLETED' else 0,
            units_pending=0 if target_state in ('COMPLETED', 'STANDBY_SEARCHING') else 1,
            status='OPEN',
            is_active=target_state != 'COMPLETED',
            is_drill=True,
            expires_at=now + timedelta(hours=6),
        )

        RequestTimelineEvent.objects.create(
            request=req,
            actor=requester,
            state='OPEN',
            note="Blood request posted by requester",
        )

        # 5. Create RequestAcceptance & DonationMatch
        chat_room_id = f"chat_{req.id}_{donor_profile.id}"
        acc_status = 'ACCEPTED'
        if target_state == 'DONOR_ON_THE_WAY':
            acc_status = 'ON_THE_WAY'
        elif target_state == 'COMPLETED':
            acc_status = 'CONFIRMED'
        elif target_state == 'STANDBY_SEARCHING':
            acc_status = 'CANCELLED'

        acc = RequestAcceptance.objects.create(
            request=req,
            donor=donor_profile,
            status=acc_status,
            support_status='CAN_SUPPORT',
            units_pledged=1,
            started_at=now,
            completed_at=now if target_state == 'COMPLETED' else None,
            donor_lat=23.7500 if target_state in ('ACCEPTED', 'DONOR_ON_THE_WAY') else None,
            donor_lng=90.3900 if target_state in ('ACCEPTED', 'DONOR_ON_THE_WAY') else None,
            last_location_update=now if target_state == 'DONOR_ON_THE_WAY' else None,
            distance_km=3.2 if target_state in ('ACCEPTED', 'DONOR_ON_THE_WAY') else None,
            eta_minutes=15 if target_state in ('ACCEPTED', 'DONOR_ON_THE_WAY') else None,
        )

        match = DonationMatch.objects.create(
            request=req,
            donor=donor_profile,
            status=acc_status,
            role='PRIMARY',
            support_status='CAN_SUPPORT',
            units_pledged=1,
            accepted_at=now,
            donated_at=now if target_state == 'COMPLETED' else None,
            confirmed_at=now if target_state == 'COMPLETED' else None,
            chat_room_id=chat_room_id,
        )

        # 6. Apply state transitions and timeline events up to target_state
        if target_state in ('ACCEPTED', 'DONOR_ON_THE_WAY', 'COMPLETED'):
            transition(req, 'ACCEPTED', donor_user, note=f"Accepted by donor {donor_profile.user.username}")

        if target_state == 'DONOR_ON_THE_WAY':
            transition(req, 'DONOR_ON_THE_WAY', donor_user, note="Donor is on the way to hospital")

        if target_state == 'STANDBY_SEARCHING':
            transition(req, 'ACCEPTED', donor_user, note="Initial donor accepted")
            transition(req, 'DONOR_CANCELLED', donor_user, note="Donor cancelled: unable to donate")
            transition(req, 'STANDBY_SEARCHING', None, note="Searching for standby replacement donor")

        if target_state == 'COMPLETED':
            transition(req, 'DONOR_ON_THE_WAY', donor_user, note="Donor on the way")
            transition(req, 'ARRIVED', donor_user, note="Donor arrived at hospital")
            transition(req, 'DONATED', donor_user, note="Donor completed blood donation")
            transition(req, 'COMPLETED', requester, note="Both sides confirmed donation completion")

        self.stdout.write(self.style.SUCCESS("=" * 60))
        self.stdout.write(self.style.SUCCESS("  [SUCCESS] Demo Journey Seeded Successfully"))
        self.stdout.write(self.style.SUCCESS("=" * 60))
        self.stdout.write(f"Request ID       : {req.id}")
        self.stdout.write(f"Acceptance ID    : {acc.id}")
        self.stdout.write(f"Journey State    : {target_state}")
        self.stdout.write(f"Requester        : {requester.username} (ID: {requester.id})")
        self.stdout.write(f"Donor            : {donor_user.username} (ID: {donor_user.id})")
        self.stdout.write(f"Chat Room ID     : {chat_room_id}")
        self.stdout.write(f"Direct Route     : /journeys/{acc.id}")
        self.stdout.write(f"Chat Route       : /chat?roomId={chat_room_id}")
        self.stdout.write(f"Tracking Route   : /blood-hub/tracking")
        self.stdout.write(self.style.SUCCESS("=" * 60))

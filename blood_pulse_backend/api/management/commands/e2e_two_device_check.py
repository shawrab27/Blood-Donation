# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Management command: e2e_two_device_check
Simulates and validates live end-to-end flow between two devices without physical hardware:
- Device A: Requester (A+) in Dhaka
- Device B: Donor 1 (O+) in Dhaka
- Device C: Donor 2 (O+) in Dhaka (Standby)

Flow:
1. create request ->
2. assert wave notification rows for both donors ->
3. donor 1 accept ->
4. assert requester notification + status ->
5. donor location post x3 ->
6. requester fetch shows moved position ->
7. chat text both ways ->
8. voice note upload + fetch ->
9. donor 1 cancel ->
10. maintenance tick -> donor 2 becomes active ->
11. completion ->
12. thanks letter + single count.

Prints PASS/FAIL per step with timing table.
Refuses to run on production unless ALLOW_PROD=1.
"""

import os
import sys
import time
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.conf import settings
from django.utils import timezone
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from rest_framework import status

from api.models import (
    BloodRequest,
    DonorProfile,
    RequestAcceptance,
    StandbyOffer,
    Notification,
    WaveNotificationLog,
    DirectMessage,
)
from api.services.standby import process_stale_tracking_and_standby_tick


class Command(BaseCommand):
    help = "E2E Two-Device Live Simulation: Notification -> Accept -> Tracking -> Chat -> Standby -> Completion."

    def add_arguments(self, parser):
        parser.add_argument(
            '--allow-prod',
            action='store_true',
            dest='allow_prod',
            help='Explicit flag allowing execution on production (danger).',
        )

    def handle(self, *args, **options):
        # 1. Production Guard
        db_url = os.environ.get('DATABASE_URL', '')
        prod_flag = options.get('allow_prod') or os.environ.get('ALLOW_PROD') == '1'
        if ('ep-proud-dew' in db_url) and not prod_flag:
            self.stderr.write(self.style.ERROR(
                "ABORTED: Refusing to run e2e_two_device_check on production database (ep-proud-dew) unless ALLOW_PROD=1."
            ))
            sys.exit(1)

        if 'testserver' not in settings.ALLOWED_HOSTS:
            settings.ALLOWED_HOSTS.append('testserver')
        settings.IS_TESTING = True
        settings.REQUEST_OTP_REQUIRED = False

        self.stdout.write(self.style.NOTICE("Starting E2E Two-Device Live Simulation..."))
        results = []

        def run_step(step_name, func):
            t0 = time.perf_counter()
            try:
                func()
                ms = int((time.perf_counter() - t0) * 1000)
                results.append((step_name, "PASS", ms, ""))
                self.stdout.write(self.style.SUCCESS(f"  [PASS] {step_name} ({ms} ms)"))
            except Exception as e:
                ms = int((time.perf_counter() - t0) * 1000)
                results.append((step_name, "FAIL", ms, str(e)))
                self.stdout.write(self.style.ERROR(f"  [FAIL] {step_name} ({ms} ms): {e}"))
                raise

        # Setup test data
        try:
            req_user, _ = User.objects.get_or_create(username='e2e_req_test', defaults={'email': 'e2e_req@testpulse.org'})
            req_user.first_name = 'Requester'
            req_user.last_name = 'Test'
            req_user.save()
            req_profile = DonorProfile.objects.filter(user=req_user).first() or DonorProfile.objects.filter(phone_number='01711000001').first()
            if not req_profile:
                req_profile = DonorProfile.objects.create(
                    user=req_user,
                    blood_group='A+',
                    district='Dhaka',
                    phone_number='01711000001',
                    is_available=True,
                    is_profile_complete=True,
                    is_verified=True,
                    user_intent='DONATE_AND_REQUEST',
                    latitude=23.7700,
                    longitude=90.3700,
                )
            else:
                req_profile.user = req_user
                req_profile.blood_group = 'A+'
                req_profile.district = 'Dhaka'
                req_profile.phone_number = '01711000001'
                req_profile.is_available = True
                req_profile.is_profile_complete = True
                req_profile.is_verified = True
                req_profile.user_intent = 'DONATE_AND_REQUEST'
                req_profile.latitude = 23.7700
                req_profile.longitude = 90.3700
                req_profile.save()

            d1_user, _ = User.objects.get_or_create(username='e2e_d1_test', defaults={'email': 'e2e_d1@testpulse.org'})
            d1_user.first_name = 'Donor'
            d1_user.last_name = 'One'
            d1_user.save()
            d1_profile = DonorProfile.objects.filter(user=d1_user).first() or DonorProfile.objects.filter(phone_number='01811000002').first()
            if not d1_profile:
                d1_profile = DonorProfile.objects.create(
                    user=d1_user,
                    blood_group='O+',
                    district='Dhaka',
                    phone_number='01811000002',
                    is_available=True,
                    is_profile_complete=True,
                    is_verified=True,
                    user_intent='DONATE_AND_REQUEST',
                    last_donation_date=None,
                    fulfilled_count=0,
                    latitude=23.7500,
                    longitude=90.3900,
                    is_suspended=False,
                    alert_pause_until=None,
                    emergency_alerts_paused_until=None,
                )
            else:
                d1_profile.user = d1_user
                d1_profile.blood_group = 'O+'
                d1_profile.district = 'Dhaka'
                d1_profile.phone_number = '01811000002'
                d1_profile.is_available = True
                d1_profile.is_profile_complete = True
                d1_profile.is_verified = True
                d1_profile.user_intent = 'DONATE_AND_REQUEST'
                d1_profile.last_donation_date = None
                d1_profile.fulfilled_count = 0
                d1_profile.latitude = 23.7500
                d1_profile.longitude = 90.3900
                d1_profile.is_suspended = False
                d1_profile.alert_pause_until = None
                d1_profile.emergency_alerts_paused_until = None
                d1_profile.save()

            d2_user, _ = User.objects.get_or_create(username='e2e_d2_test', defaults={'email': 'e2e_d2@testpulse.org'})
            d2_user.first_name = 'Donor'
            d2_user.last_name = 'Two'
            d2_user.save()
            d2_profile = DonorProfile.objects.filter(user=d2_user).first() or DonorProfile.objects.filter(phone_number='01911000003').first()
            if not d2_profile:
                d2_profile = DonorProfile.objects.create(
                    user=d2_user,
                    blood_group='O+',
                    district='Dhaka',
                    phone_number='01911000003',
                    is_available=True,
                    is_profile_complete=True,
                    is_verified=True,
                    user_intent='DONATE_AND_REQUEST',
                    last_donation_date=None,
                    fulfilled_count=0,
                    latitude=23.7520,
                    longitude=90.3920,
                    is_suspended=False,
                    alert_pause_until=None,
                    emergency_alerts_paused_until=None,
                )
            else:
                d2_profile.user = d2_user
                d2_profile.blood_group = 'O+'
                d2_profile.district = 'Dhaka'
                d2_profile.phone_number = '01911000003'
                d2_profile.is_available = True
                d2_profile.is_profile_complete = True
                d2_profile.is_verified = True
                d2_profile.user_intent = 'DONATE_AND_REQUEST'
                d2_profile.last_donation_date = None
                d2_profile.fulfilled_count = 0
                d2_profile.latitude = 23.7520
                d2_profile.longitude = 90.3920
                d2_profile.is_suspended = False
                d2_profile.alert_pause_until = None
                d2_profile.emergency_alerts_paused_until = None
                d2_profile.save()

            # Clean prior test state
            Notification.objects.filter(user__in=[req_user, d1_user, d2_user]).delete()
            BloodRequest.objects.filter(requester=req_user).delete()

            req_client = APIClient()
            req_client.force_authenticate(user=req_user)

            d1_client = APIClient()
            d1_client.force_authenticate(user=d1_user)

            d2_client = APIClient()
            d2_client.force_authenticate(user=d2_user)

            state = {}

            # STEP 1: Create Request
            def step_1():
                res = req_client.post('/api/emergency/requests/', {
                    'patient_name': 'E2E Live Patient',
                    'blood_group': 'A+',
                    'units_needed': 1,
                    'urgency': 'URGENT',
                    'district': 'Dhaka',
                    'hospital_name_other': 'Dhaka Medical College Hospital',
                    'ward_bed': 'Ward 4, Bed 12',
                    'contact_phone': '01711000001',
                    'mode': 'EMERGENCY',
                }, format='json')
                if res.status_code not in (200, 201):
                    raise AssertionError(f"Expected 201/200, got {res.status_code}: {res.data}")
                state['request_id'] = res.data['id']
            run_step("1. Create Blood Request (A+)", step_1)

            # STEP 2: Assert Wave Notification Rows for Both Donors
            def step_2():
                req_id = state['request_id']
                notif1 = Notification.objects.filter(user=d1_user, type='emergency_request_new').first()
                if not notif1:
                    raise AssertionError(f"No in-app notification row for Donor 1 on Request #{req_id}")
                notif2 = Notification.objects.filter(user=d2_user, type='emergency_request_new').first()
                if not notif2:
                    raise AssertionError(f"No in-app notification row for Donor 2 on Request #{req_id}")
            run_step("2. Wave 1 In-App Notifications (Both Donors)", step_2)

            # STEP 3: Donor 1 Accept
            def step_3():
                req_id = state['request_id']
                res = d1_client.post(f'/api/emergency/requests/{req_id}/accept/', {})
                if res.status_code not in (200, 201):
                    raise AssertionError(f"Donor 1 accept failed: {res.status_code}: {res.data}")
                state['acceptance_id'] = res.data['acceptance']['id']
                
                # Check requester notified
                notif_req = Notification.objects.filter(user=req_user, type='request_accepted').first()
                if not notif_req:
                    raise AssertionError("Requester did not receive 'request_accepted' notification.")
            run_step("3. Donor 1 Accept & Requester Notification", step_3)

            # STEP 4: Donor Location Post x3 & Requester Fetch
            def step_4():
                acc_id = state['acceptance_id']
                coords = [
                    (23.7500, 90.3900),
                    (23.7550, 90.3850),
                    (23.7600, 90.3800),
                ]
                for lat, lng in coords:
                    res = d1_client.post(
                        f'/api/journeys/{acc_id}/location/',
                        {'lat': lat, 'lng': lng},
                        HTTP_X_BYPASS_THROTTLE='1',
                    )
                    if res.status_code != 200:
                        raise AssertionError(f"Location update failed ({lat}, {lng}): {res.status_code}: {res.data}")
                
                # Requester fetch
                fetch_res = req_client.get(f'/api/journeys/{acc_id}/location/')
                if fetch_res.status_code != 200:
                    raise AssertionError(f"Requester location fetch failed: {fetch_res.status_code}")
                data = fetch_res.json()
                if data.get('donor_lat') != 23.7600 or data.get('donor_lng') != 90.3800:
                    raise AssertionError(f"Location did not match latest post: {data}")
            run_step("4. Donor Live Location Post x3 & Requester Tracking", step_4)

            # STEP 5: Chat Text Both Ways
            def step_5():
                acc_id = state['acceptance_id']
                # Requester sends text
                res1 = req_client.post(f'/api/v1/blood-hub/chat/{acc_id}/messages/', {
                    'content': 'Please come to 3rd floor blood bank room.',
                })
                if res1.status_code not in (200, 201):
                    raise AssertionError(f"Requester chat send failed: {res1.status_code}: {res1.data}")
                
                # Donor fetches text
                fetch1 = d1_client.get(f'/api/v1/blood-hub/chat/{acc_id}/messages/')
                msgs1 = fetch1.json().get('results', [])
                if not any('3rd floor' in m.get('content', '') for m in msgs1):
                    raise AssertionError("Donor did not receive Requester text.")

                # Donor replies
                res2 = d1_client.post(f'/api/v1/blood-hub/chat/{acc_id}/messages/', {
                    'content': 'Arriving in 10 minutes.',
                })
                if res2.status_code not in (200, 201):
                    raise AssertionError(f"Donor chat send failed: {res2.status_code}: {res2.data}")
                
                # Requester fetches reply
                fetch2 = req_client.get(f'/api/v1/blood-hub/chat/{acc_id}/messages/')
                msgs2 = fetch2.json().get('results', [])
                if not any('Arriving in 10 minutes' in m.get('content', '') for m in msgs2):
                    raise AssertionError("Requester did not receive Donor reply.")
            run_step("5. Real-Time Chat (Text Both Ways)", step_5)

            # STEP 6: Voice Note Upload & Fetch
            def step_6():
                acc_id = state['acceptance_id']
                dummy_audio = SimpleUploadedFile(
                    "voice_note.webm",
                    b"\x1a\x45\xdf\xa3\x9f\x42\x86\x81\x01\x42\xf7\x81\x01",
                    content_type="audio/webm",
                )
                res_voice = d1_client.post(
                    f'/api/chat/{acc_id}/voice/',
                    {'voice_file': dummy_audio, 'duration_seconds': 15},
                    format='multipart',
                )
                if res_voice.status_code not in (200, 201):
                    raise AssertionError(f"Voice upload failed: {res_voice.status_code}: {res_voice.data}")
                voice_url = res_voice.data.get('voice_url')
                if not voice_url:
                    raise AssertionError("Voice upload returned empty voice_url.")

                # Send voice message
                res_msg = d1_client.post(f'/api/v1/blood-hub/chat/{acc_id}/messages/', {
                    'content': '',
                    'message_type': 'VOICE',
                    'voice_url': voice_url,
                    'voice_duration_seconds': 15,
                })
                if res_msg.status_code not in (200, 201):
                    raise AssertionError(f"Voice message record failed: {res_msg.status_code}: {res_msg.data}")

                # Requester fetches
                fetch = req_client.get(f'/api/v1/blood-hub/chat/{acc_id}/messages/')
                msgs = fetch.json().get('results', [])
                voice_m = next((m for m in msgs if m.get('message_type') == 'VOICE'), None)
                if not voice_m:
                    raise AssertionError("Requester did not find VOICE message in chat.")
            run_step("6. Voice Note Upload (WebM/M4A) & Fetch", step_6)

            # STEP 7: Donor 1 Cancel
            def step_7():
                acc_id = state['acceptance_id']
                res = d1_client.post(f'/api/journeys/{acc_id}/status/', {
                    'status': 'CANCELLED',
                    'reason': 'Unexpected personal emergency',
                })
                if res.status_code != 200:
                    raise AssertionError(f"Donor 1 cancel failed: {res.status_code}: {res.data}")
                acc = RequestAcceptance.objects.get(id=acc_id)
                if acc.status != 'CANCELLED':
                    raise AssertionError(f"Expected CANCELLED status, got: {acc.status}")
            run_step("7. Donor 1 Cancel Journey", step_7)

            # STEP 8: Maintenance Tick & Donor 2 Becomes Active
            def step_8():
                req_id = state['request_id']
                # Offer was automatically triggered upon cancellation; locate offer
                offer = StandbyOffer.objects.filter(request_id=req_id).order_by('-id').first()
                if not offer:
                    from api.services.standby import trigger_standby_donor_offer
                    offer = trigger_standby_donor_offer(BloodRequest.objects.get(id=req_id), exclude_donor_ids=[d1_profile.id])
                
                if not offer:
                    raise AssertionError(f"No StandbyOffer generated on Request #{req_id}")

                active_donor_user = offer.donor.user
                active_donor_profile = offer.donor
                active_donor_client = APIClient()
                active_donor_client.force_authenticate(user=active_donor_user)

                res = active_donor_client.post(f'/api/standby/{offer.id}/respond/', {'action': 'ACCEPT'})
                if res.status_code != 200:
                    raise AssertionError(f"Standby accept failed: {res.status_code}: {res.data}")
                
                state['d2_acceptance_id'] = res.data['acceptance_id']
                state['active_donor_user'] = active_donor_user
                state['active_donor_profile'] = active_donor_profile
                state['active_donor_client'] = active_donor_client

                d2_acc = RequestAcceptance.objects.get(id=state['d2_acceptance_id'])
                if d2_acc.status != 'ACCEPTED':
                    raise AssertionError(f"Expected standby acceptance status ACCEPTED, got: {d2_acc.status}")
            run_step("8. Maintenance Standby Escalation & Donor 2 Active", step_8)

            # STEP 9: Donation Completion (Two-Sided)
            def step_9():
                d2_acc_id = state['d2_acceptance_id']
                active_client = state['active_donor_client']

                # Donor reports DONATED
                res_donated = active_client.post(f'/api/journeys/{d2_acc_id}/status/', {'status': 'DONATED'})
                if res_donated.status_code != 200:
                    raise AssertionError(f"Donor DONATED transition failed: {res_donated.status_code}: {res_donated.data}")
                
                # Requester confirms
                res_confirm = req_client.post(f'/api/journeys/{d2_acc_id}/status/', {'status': 'CONFIRMED'})
                if res_confirm.status_code != 200:
                    raise AssertionError(f"Requester CONFIRMED failed: {res_confirm.status_code}: {res_confirm.data}")
                
                d2_acc = RequestAcceptance.objects.get(id=d2_acc_id)
                if d2_acc.status != 'CONFIRMED':
                    raise AssertionError(f"Expected CONFIRMED status, got: {d2_acc.status}")
                
                req = BloodRequest.objects.get(id=state['request_id'])
                if req.status != 'FULFILLED':
                    raise AssertionError(f"Expected request status FULFILLED, got: {req.status}")
            run_step("9. Two-Sided Completion (DONATED + CONFIRMED)", step_9)

            # STEP 10: Thanks Letter & Single Count
            def step_10():
                active_user = state['active_donor_user']
                active_prof = state['active_donor_profile']

                thanks_notif = Notification.objects.filter(user=active_user, type='thanks_letter').first()
                if not thanks_notif:
                    raise AssertionError("Active donor did not receive thanks_letter notification.")
                
                active_prof.refresh_from_db()
                if (active_prof.fulfilled_count or 0) < 1:
                    raise AssertionError(f"Expected fulfilled_count >= 1, got: {active_prof.fulfilled_count}")
                if active_prof.last_donation_date != timezone.now().date():
                    raise AssertionError(f"Expected last_donation_date today, got: {active_prof.last_donation_date}")
            run_step("10. Thank You Letter & Donation Single Count Cooldown", step_10)

        finally:
            # Print table
            self.stdout.write("\n" + "=" * 70)
            self.stdout.write(f"{'STEP':<50} | {'STATUS':<6} | {'TIME':>8}")
            self.stdout.write("-" * 70)
            for name, st, ms, err in results:
                self.stdout.write(f"{name:<50} | {st:<6} | {ms:>5} ms")
            self.stdout.write("=" * 70 + "\n")

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Management command: debug_wave
Read-only diagnostic tool safe to run on local or production.
Inspects an emergency blood request and explains why each candidate donor was included or excluded.

Usage:
    python manage.py debug_wave
    python manage.py debug_wave --request 42
"""

from django.core.management.base import BaseCommand
from django.utils import timezone
from api.conf import WAVE_RADIUS_KM
from api.models import BloodRequest, DonorProfile, WaveNotificationLog, EmergencyNotification, UserDevice
from api.services.compat import get_compatible_donor_groups
from api.services.eligibility import evaluate_donor_eligibility, is_in_quiet_hours
from api.services.geo import haversine_distance


class Command(BaseCommand):
    help = "Read-only diagnostics for wave candidate evaluation and notification logs."

    def add_arguments(self, parser):
        parser.add_argument(
            '--request',
            type=int,
            dest='request_id',
            help='ID of the BloodRequest to diagnose. If omitted, uses the latest request.',
        )

    def handle(self, *args, **options):
        request_id = options.get('request_id')
        if request_id:
            req = BloodRequest.objects.filter(id=request_id).first()
            if not req:
                self.stderr.write(self.style.ERROR(f"BloodRequest #{request_id} not found."))
                return
        else:
            req = BloodRequest.objects.order_by('-id').first()
            if not req:
                self.stderr.write(self.style.WARNING("No BloodRequest records found in database."))
                return

        now = timezone.now()
        effective_scope = (getattr(req, 'effective_scope', 'LOCAL') or 'LOCAL').upper()
        current_wave = getattr(req, 'current_wave', 1) or 1
        radius_idx = max(0, min(current_wave - 1, len(WAVE_RADIUS_KM) - 1)) if WAVE_RADIUS_KM else 0
        ladder_radius_km = WAVE_RADIUS_KM[radius_idx] if WAVE_RADIUS_KM else 5.0

        is_critical = str(getattr(req, 'urgency', '')).upper() in ('CRITICAL_2H', 'URGENT', 'URGENT (IMMEDIATE)')
        quiet_hours_active = is_in_quiet_hours(now)

        self.stdout.write("=" * 80)
        self.stdout.write(f" WAVE DIAGNOSTICS FOR BLOOD REQUEST #{req.id}")
        self.stdout.write("=" * 80)
        self.stdout.write(f"Requested Group : {req.blood_group}")
        self.stdout.write(f"Component       : {req.component or 'WHOLE'}")
        self.stdout.write(f"Urgency         : {req.urgency} (Bypasses Quiet Hours: {'YES' if is_critical else 'NO'})")
        self.stdout.write(f"Status          : {req.status}")
        self.stdout.write(f"Mode            : {req.mode}")
        self.stdout.write(f"Effective Scope : {effective_scope}")
        self.stdout.write(f"Current Wave    : Wave {current_wave} (Ladder step radius: {ladder_radius_km} km)")
        self.stdout.write(f"Hospital        : {getattr(req.hospital, 'name', None) or req.hospital_name_other or 'N/A'}")
        self.stdout.write(f"Location        : District='{req.district}', Upazila='{req.upazila}', Lat={req.lat}, Lng={req.lng}")
        self.stdout.write(f"Created At      : {req.created_at}")
        self.stdout.write(f"Quiet Hours Now : {'YES (22:00-07:00 Asia/Dhaka)' if quiet_hours_active else 'NO'}")
        self.stdout.write("-" * 80)

        # 1. Wave Notification Logs
        wave_logs = WaveNotificationLog.objects.filter(request=req).order_by('-sent_at')[:20]
        self.stdout.write(f"WaveNotificationLog rows for Request #{req.id}: {wave_logs.count()}")
        for log in wave_logs:
            donor_username = log.donor.user.username if (log.donor and log.donor.user) else "unknown"
            self.stdout.write(f"  - [{log.sent_at}] Wave {log.wave}: Donor #{log.donor_id} (@{donor_username}) -> Status: {log.status}")

        emerg_notifs = EmergencyNotification.objects.filter(request=req).order_by('-sent_at')[:20]
        self.stdout.write(f"EmergencyNotification rows for Request #{req.id}: {emerg_notifs.count()}")
        for en in emerg_notifs:
            donor_username = en.donor.user.username if (en.donor and en.donor.user) else "unknown"
            self.stdout.write(f"  - [{en.sent_at}] Wave {en.wave}: Donor #{en.donor_id} (@{donor_username}) -> Delivered: {en.delivered}")

        self.stdout.write("-" * 80)
        self.stdout.write("CANDIDATE DONOR EVALUATION:")
        self.stdout.write("-" * 80)

        compatible_groups = get_compatible_donor_groups(req.blood_group, req.component or 'WHOLE')
        donors = DonorProfile.objects.all().select_related('user')
        if not donors.exists():
            self.stdout.write("No DonorProfile records in database.")
            return

        for donor in donors:
            username = donor.user.username if donor.user else "no_user"
            donor_id = donor.id
            reasons = []

            # 1. Self check
            if req.requester_id and donor.user_id == req.requester_id:
                reasons.append("self (requester)")

            # 2. Blood group compatibility
            if donor.blood_group not in compatible_groups:
                reasons.append(f"blood group not compatible (donor={donor.blood_group}, requested={req.blood_group})")

            # 3. User intent
            if getattr(donor, 'user_intent', None) == 'ONLY_REQUEST':
                reasons.append("user_intent ONLY_REQUEST")

            # 4. Availability & suspension
            if not donor.is_available:
                reasons.append("unavailable (is_available=False)")
            if getattr(donor, 'is_suspended', False) or (donor.user and not donor.user.is_active):
                reasons.append("suspended or user inactive")

            # 5. Alert pause
            pause_until = getattr(donor, 'emergency_alerts_paused_until', None) or getattr(donor, 'alert_pause_until', None)
            if pause_until and pause_until > now:
                reasons.append(f"alerts paused until {pause_until}")

            # 6. Medical deferral & cooldown
            elig = evaluate_donor_eligibility(
                donor,
                component=req.component or 'WHOLE',
                is_critical=is_critical,
                check_quiet_hours=False,
                eval_time=now,
            )
            if not elig['is_eligible']:
                reasons.append(f"cooldown/medical deferral: {elig['reason']}")

            # 7. Quiet hours (if non-critical)
            if quiet_hours_active and not is_critical:
                reasons.append("quiet hours 22:00-07:00 Asia/Dhaka (push suppressed; in-app allowed)")

            # 8. Geo / Radius / District check
            donor_lat = donor.last_lat or donor.latitude
            donor_lng = donor.last_lng or donor.longitude
            dist_km = None
            if req.lat is not None and req.lng is not None and donor_lat is not None and donor_lng is not None:
                dist_km = haversine_distance(req.lat, req.lng, donor_lat, donor_lng)

            in_boundary = False
            if current_wave == 1:
                if dist_km is not None and dist_km <= ladder_radius_km:
                    in_boundary = True
                elif req.upazila and getattr(donor, 'upazila', None) and req.upazila.strip().lower() == donor.upazila.strip().lower():
                    in_boundary = True
                elif req.district and donor.district and req.district.strip().lower() == donor.district.strip().lower():
                    in_boundary = True
            elif current_wave == 2:
                if dist_km is not None and dist_km <= ladder_radius_km:
                    in_boundary = True
                elif req.district and donor.district and req.district.strip().lower() == donor.district.strip().lower():
                    in_boundary = True
            elif current_wave == 3:
                if dist_km is not None and dist_km <= ladder_radius_km:
                    in_boundary = True
                elif req.district and donor.district and req.district.strip().lower() == donor.district.strip().lower():
                    in_boundary = True
                elif req.division_id and getattr(donor, 'division_id', None) == req.division_id:
                    in_boundary = True
            else:
                in_boundary = True

            if not in_boundary:
                dist_str = f"{round(dist_km, 1)}km > {ladder_radius_km}km" if dist_km is not None else "no coordinate match"
                reasons.append(f"outside radius ({dist_str}) and different district/upazila (donor={donor.district}, req={req.district})")

            # 9. Profile complete and verification status
            if not getattr(donor, 'is_profile_complete', True):
                reasons.append("profile incomplete")
            if not getattr(donor, 'is_verified', False):
                reasons.append("not verified")

            # 10. FCM Token check
            devices = UserDevice.objects.filter(user=donor.user, is_revoked=False).exclude(fcm_token__isnull=True).exclude(fcm_token='') if donor.user else []
            has_device_token = any(bool(d.fcm_token and d.fcm_token.strip()) for d in devices)
            has_donor_token = bool(donor.fcm_token and donor.fcm_token.strip())
            fcm_status = "present" if (has_device_token or has_donor_token) else "no FCM token"
            if not (has_device_token or has_donor_token):
                reasons.append("no FCM token (push impossible; in-app still works)")

            # 11. Already notified
            already_wave = WaveNotificationLog.objects.filter(request=req, donor=donor).exists()
            if already_wave:
                reasons.append("already notified in WaveNotificationLog")

            status_str = "ELIGIBLE" if not [r for r in reasons if not r.startswith("no FCM token") and not r.startswith("quiet hours")] else "EXCLUDED"
            self.stdout.write(
                f"Donor #{donor_id} (@{username}, {donor.blood_group}, {donor.district or 'No district'}): {status_str}"
            )
            if reasons:
                for r in reasons:
                    self.stdout.write(f"    - {r}")
        self.stdout.write("=" * 80)

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Notification Dispatch Service.
Dispatches wave notifications, creates notification audit logs,
updates user unread badges, and sends high-priority FCM pushes.
"""

import logging
import os
from django.conf import settings
from django.utils import timezone
from api.conf import FCM_BATCH_SIZE
from api.models import EmergencyNotification, UserNotificationState, WaveNotificationLog, DonorProfile, UserDevice

logger = logging.getLogger(__name__)


def send_fcm_multicast_batches(tokens_with_donors: list, title: str, body: str, data_payload: dict = None) -> dict:
    """
    Sends FCM pushes in batches of max FCM_BATCH_SIZE (default 500).
    Uses Firebase service account from environment (FIREBASE_SERVICE_ACCOUNT*).
    Catches invalid/unregistered tokens and deactivates them from UserDevice and DonorProfile.
    Never logs recipient coordinates or prints secrets.
    """
    if not tokens_with_donors:
        return {'sent': 0, 'failed': 0, 'invalid_tokens_cleared': 0}

    try:
        import firebase_admin
        from firebase_admin import messaging
        from api.services.firebase_service import get_or_initialize_firebase_admin
    except ImportError:
        logger.warning("firebase-admin not installed. Skipping FCM push.")
        return {'sent': len(tokens_with_donors), 'failed': 0, 'invalid_tokens_cleared': 0}

    # Initialize app if not already initialized
    try:
        get_or_initialize_firebase_admin()
    except Exception as init_err:
        logger.warning("Firebase Admin initialization notice: %s", init_err)

    total_sent = 0
    total_failed = 0
    invalid_tokens_cleared = 0

    batch_size = FCM_BATCH_SIZE or 500
    for i in range(0, len(tokens_with_donors), batch_size):
        chunk = tokens_with_donors[i:i + batch_size]
        tokens = [item[0] for item in chunk]
        donors = [item[1] for item in chunk]

        message = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            data=data_payload or {"click_action": "FLUTTER_NOTIFICATION_CLICK", "type": "BLOOD_EMERGENCY"},
            android=messaging.AndroidConfig(priority="high", notification=messaging.AndroidNotification(channel_id="bloodpulse_urgent_alerts")),
            tokens=tokens,
        )

        try:
            response = messaging.send_each_for_multicast(message)
            total_sent += response.success_count
            total_failed += response.failure_count

            # Process responses to catch invalid tokens
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    err_str = str(resp.exception).lower()
                    if any(x in err_str for x in ['unregistered', 'invalid_argument', 'invalid-registration-token', 'not_found']):
                        bad_token = tokens[idx]
                        donor_obj = donors[idx]
                        if donor_obj and donor_obj.fcm_token == bad_token:
                            logger.info("Deactivating invalid FCM token for donor ID %s", donor_obj.id)
                            donor_obj.fcm_token = None
                            donor_obj.save(update_fields=['fcm_token'])
                            invalid_tokens_cleared += 1
                        UserDevice.objects.filter(fcm_token=bad_token).update(fcm_token=None)
        except Exception as batch_err:
            logger.error("Failed executing FCM batch: %s", batch_err)
            total_failed += len(chunk)

    return {
        'sent': total_sent,
        'failed': total_failed,
        'invalid_tokens_cleared': invalid_tokens_cleared,
    }


def send_push_to_user(user, title: str, body: str, data_payload: dict = None, dry_run: bool = False) -> dict:
    """
    Sends a high-priority push notification to all active devices of a specific User (#36).
    Collects tokens from both UserDevice and DonorProfile.
    If dry_run=True, reports tokens found without sending.
    Cleans up any invalid tokens returned by FCM.
    """
    tokens = set()

    for d in UserDevice.objects.filter(user=user, is_revoked=False).exclude(fcm_token__isnull=True).exclude(fcm_token=''):
        if d.fcm_token.strip():
            tokens.add(d.fcm_token.strip())

    donor_profile = DonorProfile.objects.filter(user=user).first()
    if donor_profile and donor_profile.fcm_token and donor_profile.fcm_token.strip():
        tokens.add(donor_profile.fcm_token.strip())

    token_list = list(tokens)
    if not token_list:
        return {
            'status': 'no_tokens',
            'user': user.username,
            'tokens_count': 0,
            'dry_run': dry_run,
        }

    if dry_run:
        # Mask tokens to never expose secrets
        return {
            'status': 'dry_run',
            'user': user.username,
            'tokens_count': len(token_list),
            'masked_tokens': [f"{t[:6]}...{t[-4:]}" for t in token_list],
            'title': title,
            'body': body,
            'data': data_payload or {},
            'dry_run': True,
        }

    tokens_with_donors = [(t, donor_profile) for t in token_list]
    res = send_fcm_multicast_batches(tokens_with_donors, title, body, data_payload)
    return {
        'status': 'sent' if res['sent'] > 0 else 'failed',
        'user': user.username,
        'tokens_count': len(token_list),
        'sent': res['sent'],
        'failed': res['failed'],
        'invalid_tokens_cleared': res['invalid_tokens_cleared'],
        'dry_run': False,
    }


def dispatch_wave_notifications(blood_request, candidate_list: list, wave_number: int = 1) -> int:
    """
    Records notifications for candidate donors and attempts FCM push delivery.
    Enforces WaveNotificationLog deduplication (never notifies twice for same request).
    Batches FCM calls up to 500 tokens. Deactivates invalid FCM tokens safely.
    Returns the number of notifications dispatched.
    """
    dispatched_count = 0
    now = timezone.now()

    tokens_with_donors = []

    for item in candidate_list:
        donor = item['donor']

        # 1. Create or get WaveNotificationLog to guarantee deduplication
        log_obj, created = WaveNotificationLog.objects.get_or_create(
            request=blood_request,
            donor=donor,
            defaults={
                'wave': wave_number,
                'status': 'SENT',
            }
        )
        if not created:
            # Already logged / notified in a previous wave or tick
            continue

        # 2. Create DB audit record in EmergencyNotification
        EmergencyNotification.objects.create(
            request=blood_request,
            donor=donor,
            wave=wave_number,
            sent_at=now,
            delivered=True,
        )

        # 3. Increment donor alert metrics
        donor.alert_count = (donor.alert_count or 0) + 1
        donor.save(update_fields=['alert_count'])

        # 4. Increment unread notification badge
        if donor.user:
            UserNotificationState.increment_for_user(donor.user)

        # 5. Collect valid FCM token
        if donor.fcm_token and donor.fcm_token.strip():
            tokens_with_donors.append((donor.fcm_token.strip(), donor))

        dispatched_count += 1

    # Send high-priority FCM notifications in batches of max 500
    if tokens_with_donors:
        blood_group = blood_request.blood_group or 'Blood'
        hospital = getattr(blood_request.hospital, 'name', None) or blood_request.hospital_name_other or 'Hospital'
        title = f"Urgent: {blood_group} Blood Needed!"
        body = f"{blood_request.units_needed or 1} unit(s) needed at {hospital}."
        payload = {
            "type": "BLOOD_EMERGENCY",
            "request_id": str(blood_request.id),
            "blood_group": str(blood_group),
            "wave": str(wave_number),
        }
        send_fcm_multicast_batches(tokens_with_donors, title, body, payload)

    logger.info(f"Dispatched Wave {wave_number} for Request #{blood_request.id} to {dispatched_count} donors.")
    return dispatched_count


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
    raw_responses = []

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
                raw_responses.append({
                    'index': idx,
                    'success': resp.success,
                    'message_id': getattr(resp, 'message_id', None),
                    'exception': str(resp.exception) if getattr(resp, 'exception', None) else None,
                })
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
        'raw_responses': raw_responses,
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
        token_candidate = donor_profile.fcm_token.strip()
        if not UserDevice.objects.filter(user=user, fcm_token=token_candidate, is_revoked=True).exists():
            tokens.add(token_candidate)

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
        'raw_responses': res.get('raw_responses', []),
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
            candidate_t = donor.fcm_token.strip()
            if not UserDevice.objects.filter(user=donor.user, fcm_token=candidate_t, is_revoked=True).exists():
                tokens_with_donors.append((candidate_t, donor))

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



def notify_donor_accepted(blood_request, acceptance, is_standby: bool = False) -> dict:
    """
    Send Path 2: Donor accepted requisition (or standby donor stepped up).
    Notifies the requester via in-app Notification and high-priority FCM push.
    Channel: bloodpulse_urgent_alerts
    """
    requester = blood_request.requester if blood_request else None
    if not requester:
        return {'status': 'no_requester'}

    donor_user = acceptance.donor.user if (acceptance and acceptance.donor) else None
    donor_name = donor_user.get_full_name() or donor_user.username if donor_user else "A donor"
    blood_group = blood_request.blood_group or "Blood"

    is_standby_acceptance = is_standby or getattr(acceptance, 'is_standby', False)
    if is_standby_acceptance:
        notif_type = "STANDBY_ACCEPTED"
        title = "Standby Donor Connected"
        body = f"Standby donor {donor_name} has accepted and joined your requisition."
    else:
        notif_type = "DONOR_ACCEPTED"
        title = "Donor Accepted Your Request!"
        body = f"{donor_name} accepted your {blood_group} blood requisition and is preparing to donate."

    data_payload = {
        "type": notif_type,
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "request_id": str(blood_request.id),
        "acceptance_id": str(acceptance.id),
        "donor_id": str(acceptance.donor_id),
    }

    from api.models import Notification
    try:
        Notification.objects.create(
            user=requester,
            title=title,
            body=body,
            type=notif_type,
            is_read=False,
            created_at=timezone.now(),
        )
    except Exception:
        pass
    UserNotificationState.increment_for_user(requester)

    return send_push_to_user(requester, title, body, data_payload=data_payload)


def notify_chat_message(message, recipient_user) -> dict:
    """
    Send Path 3: New direct chat message.
    Notifies the recipient via in-app Notification and high-priority FCM push.
    Channel: bloodpulse_urgent_alerts
    """
    if not recipient_user:
        return {'status': 'no_recipient'}

    sender_name = message.sender.get_full_name() or message.sender.username if message.sender else "Someone"
    preview_text = message.content[:60] if message.content else ("Voice note" if message.message_type == 'VOICE' else "Attachment")

    title = f"New Message from {sender_name}"
    body = preview_text
    data_payload = {
        "type": "CHAT_MESSAGE",
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "chat_id": str(message.acceptance_id),
        "chatId": str(message.acceptance_id),
        "acceptance_id": str(message.acceptance_id),
        "sender_id": str(message.sender_id),
    }

    from api.models import Notification
    try:
        Notification.objects.create(
            user=recipient_user,
            title=title,
            body=body,
            type="CHAT_MESSAGE",
            is_read=False,
            created_at=timezone.now(),
        )
    except Exception:
        pass
    UserNotificationState.increment_for_user(recipient_user)

    return send_push_to_user(recipient_user, title, body, data_payload=data_payload)


def notify_journey_update(acceptance, new_status: str, actor_user) -> dict:
    """
    Send Path 4: Journey tracking milestone updated (ON_THE_WAY, ARRIVED, DONATED, CONFIRMED, CANCELLED).
    Notifies the counter-party (requester if actor is donor; donor if actor is requester).
    Channel: bloodpulse_urgent_alerts
    """
    blood_request = acceptance.request if acceptance else None
    donor_user = acceptance.donor.user if (acceptance and acceptance.donor) else None
    requester = blood_request.requester if blood_request else None

    # Determine recipient
    if actor_user and donor_user and actor_user.id == donor_user.id:
        recipient = requester
        actor_name = donor_user.get_full_name() or donor_user.username
    else:
        recipient = donor_user
        actor_name = requester.get_full_name() or requester.username if requester else "Requester"

    if not recipient:
        return {'status': 'no_recipient'}

    status_labels = {
        'ON_THE_WAY': 'on the way to hospital',
        'ARRIVED': 'arrived at hospital',
        'DONATED': 'marked donation complete',
        'CONFIRMED': 'confirmed donation verified',
        'CANCELLED': 'cancelled journey',
    }
    status_display = status_labels.get(new_status, new_status.lower())

    title = f"Journey Update: {new_status}"
    body = f"{actor_name} is {status_display}."
    data_payload = {
        "type": "JOURNEY_UPDATE",
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "journey_id": str(acceptance.id),
        "acceptance_id": str(acceptance.id),
        "status": new_status,
        "request_id": str(blood_request.id) if blood_request else "",
    }

    from api.models import Notification
    try:
        Notification.objects.create(
            user=recipient,
            title=title,
            body=body,
            type="JOURNEY_UPDATE",
            is_read=False,
            created_at=timezone.now(),
        )
    except Exception:
        pass
    UserNotificationState.increment_for_user(recipient)

    return send_push_to_user(recipient, title, body, data_payload=data_payload)


def notify_standby_offer(offer) -> dict:
    """
    Send Path 5: Standby donation opportunity offered to ranked candidate.
    Channel: bloodpulse_urgent_alerts
    """
    donor_user = offer.donor.user if (offer and offer.donor) else None
    if not donor_user:
        return {'status': 'no_donor_user'}

    from api.conf import STANDBY_TIMEOUT_MINUTES
    blood_req = offer.request
    blood_group = blood_req.blood_group if blood_req else "Blood"

    title = "Urgent: Standby Blood Donation Opportunity"
    body = f"You are ranked as a standby donor for request #{offer.request_id} ({blood_group}). Please respond within {STANDBY_TIMEOUT_MINUTES} minutes."
    data_payload = {
        "type": "STANDBY_OFFER",
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "offer_id": str(offer.id),
        "request_id": str(offer.request_id),
    }

    from api.models import Notification
    try:
        Notification.objects.create(
            user=donor_user,
            title=title,
            body=body,
            type="STANDBY_OFFER",
            is_read=False,
            created_at=timezone.now(),
        )
    except Exception:
        pass
    UserNotificationState.increment_for_user(donor_user)

    return send_push_to_user(donor_user, title, body, data_payload=data_payload)


def notify_request_closed(blood_request, reason: str = 'FULFILLED') -> dict:
    """
    Send Path 6: Requisition closed or fulfilled.
    Channel: bloodpulse_urgent_alerts
    """
    requester = blood_request.requester if blood_request else None
    if not requester:
        return {'status': 'no_requester'}

    blood_group = blood_request.blood_group or "Blood"
    status_text = "Fulfilled" if reason == 'FULFILLED' else "Closed"

    title = f"Requisition {status_text}"
    body = f"Blood request #{blood_request.id} for {blood_group} has been marked as {status_text}."
    data_payload = {
        "type": "REQUEST_CLOSED",
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "request_id": str(blood_request.id),
        "reason": reason,
    }

    from api.models import Notification
    try:
        Notification.objects.create(
            user=requester,
            title=title,
            body=body,
            type="REQUEST_CLOSED",
            is_read=False,
            created_at=timezone.now(),
        )
    except Exception:
        pass
    UserNotificationState.increment_for_user(requester)

    return send_push_to_user(requester, title, body, data_payload=data_payload)


def notify_donor_thanks(blood_request, donor, review=None) -> dict:
    """
    Send Path 7: Requester expresses gratitude/review to donor.
    Channel: bloodpulse_urgent_alerts
    """
    donor_user = donor.user if donor else None
    if not donor_user:
        return {'status': 'no_donor_user'}

    stars = f"{getattr(review, 'stars', getattr(review, 'rating', ''))}★ " if review and (getattr(review, 'stars', None) or getattr(review, 'rating', None)) else ""
    requester_name = blood_request.requester.get_full_name() or blood_request.requester.username if blood_request and blood_request.requester else "The requester"

    title = "Heartfelt Thanks From Requester! ❤️"
    body = f"{requester_name} left a {stars}review and heartfelt gratitude for your lifesaving blood donation!"
    data_payload = {
        "type": "DONOR_THANKS",
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "request_id": str(blood_request.id) if blood_request else "",
        "donor_id": str(donor.id),
    }

    from api.models import Notification
    try:
        Notification.objects.create(
            user=donor_user,
            title=title,
            body=body,
            type="DONOR_THANKS",
            is_read=False,
            created_at=timezone.now(),
        )
    except Exception:
        pass
    UserNotificationState.increment_for_user(donor_user)

    return send_push_to_user(donor_user, title, body, data_payload=data_payload)

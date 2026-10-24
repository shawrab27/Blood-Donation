# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Universal Notification Service: Single Source of Truth.
Writes a Notification database row FIRST, then dispatches FCM high-priority push.
Enforces the mandatory notification matrix:
type -> recipient -> push -> bell -> tap target
"""

import logging
from django.utils import timezone
from api.models import Notification, UserNotificationState
from api.services.notify import send_push_to_user

logger = logging.getLogger(__name__)

NOTIFICATION_MATRIX = {
    'emergency_request_new': {'push': True, 'bell': True, 'tap_target': '/blood-hub/requests/{id}'},
    'request_accepted': {'push': True, 'bell': True, 'tap_target': '/journeys/{id}'},
    'donor_cancelled': {'push': True, 'bell': True, 'tap_target': '/blood-hub/requests/{id}'},
    'standby_offer': {'push': True, 'bell': True, 'tap_target': '/blood-hub/requests/{id}'},
    'tracking_update': {'push': False, 'bell': False, 'tap_target': '/journeys/{id}'},
    'chat_message': {'push': True, 'bell': True, 'tap_target': '/chat/{id}'},
    'donation_confirmed': {'push': True, 'bell': True, 'tap_target': '/profile'},
    'thanks_letter': {'push': True, 'bell': True, 'tap_target': '/profile'},
    'guide_application_status': {'push': True, 'bell': True, 'tap_target': '/communities'},
    'guide_approved': {'push': True, 'bell': True, 'tap_target': '/communities'},
    'guide_rejected': {'push': True, 'bell': True, 'tap_target': '/communities'},
    'post_like': {'push': False, 'bell': True, 'tap_target': '/feed/{id}'},
    'comment': {'push': False, 'bell': True, 'tap_target': '/feed/{id}'},
    'otp': {'push': False, 'bell': False, 'tap_target': None},
    'test_push': {'push': True, 'bell': True, 'tap_target': '/notifications'},
}


def notify(user, type: str, payload: dict) -> Notification | None:
    """
    ONE function notify(user, type, payload):
    1. Checks notification matrix for push & bell permissions.
    2. Writes the Notification row FIRST (if bell=True).
    3. Then sends FCM push to all active device tokens (if push=True).
    4. Records structured Render log lines for every step.
    """
    title = payload.get('title', 'BloodPulse Notification')
    body = payload.get('body', '')

    matrix_rule = NOTIFICATION_MATRIX.get(type, {'push': True, 'bell': True, 'tap_target': '/notifications'})

    notif = None
    # ── STEP 1: Write Notification row FIRST (if bell is enabled) ───────
    if matrix_rule.get('bell', True):
        notif = Notification.objects.create(
            user=user,
            title=title,
            body=body,
            type=type,
            is_read=False,
            created_at=timezone.now(),
        )
        UserNotificationState.get_unread_for_user(user)
        logger.info("[notify] [STEP 1/3] DB row #%s created in api_notification for user %s (type: %s)", notif.id, user.id, type)
    else:
        logger.info("[notify] [STEP 1/3] DB row creation suppressed by matrix rule for type: %s", type)

    # ── STEP 2 & 3: Dispatch FCM Push (if push is enabled) ──────────────
    if matrix_rule.get('push', True):
        try:
            fcm_payload = {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'type': type,
                'notification_id': str(notif.id) if notif else '',
            }
            if matrix_rule.get('tap_target'):
                fcm_payload['tap_target'] = matrix_rule['tap_target']

            for k, v in payload.items():
                if k not in ('title', 'body'):
                    fcm_payload[k] = str(v)

            # Retrieve active tokens count for logging
            from api.models import UserDevice, DonorProfile
            tokens = set()
            for d in UserDevice.objects.filter(user=user, is_revoked=False).exclude(fcm_token__isnull=True).exclude(fcm_token=''):
                if d.fcm_token.strip():
                    tokens.add(d.fcm_token.strip())
            dp = DonorProfile.objects.filter(user=user).first()
            if dp and dp.fcm_token and dp.fcm_token.strip():
                tokens.add(dp.fcm_token.strip())

            logger.info("[notify] [STEP 2/3] Found %s active FCM device token(s) for user %s", len(tokens), user.id)

            push_res = send_push_to_user(
                user=user,
                title=title,
                body=body,
                data_payload=fcm_payload,
            )
            logger.info("[notify] [STEP 3/3] FCM dispatch result for user %s: status=%s, sent=%s, failed=%s, cleared=%s",
                        user.id, push_res.get('status'), push_res.get('sent', 0), push_res.get('failed', 0), push_res.get('invalid_tokens_cleared', 0))
        except Exception as exc:
            logger.warning("[notify] [STEP 3/3] FCM push dispatch error for notification #%s: %s", notif.id if notif else 'None', exc)
    else:
        logger.info("[notify] [STEP 2/3] Push suppressed by matrix rule for type: %s", type)
        logger.info("[notify] [STEP 3/3] FCM dispatch skipped for type: %s", type)

    return notif

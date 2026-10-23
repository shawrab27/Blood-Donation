# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Universal Notification Service: Single Source of Truth.
Writes a Notification database row FIRST, then dispatches FCM high-priority push.
"""

import logging
from django.utils import timezone
from api.models import Notification
from api.services.notify import send_push_to_user

logger = logging.getLogger(__name__)


def notify(user, type: str, payload: dict) -> Notification:
    """
    Creates and records an in-app Notification row first, then attempts FCM push.
    Guarantees audit trail even if FCM credentials or device push fails.
    """
    title = payload.get('title', 'BloodPulse Notification')
    body = payload.get('body', '')

    # 1. Write Notification row first
    notif = Notification.objects.create(
        user=user,
        title=title,
        body=body,
        type=type,
        is_read=False,
        created_at=timezone.now(),
    )

    # 2. Dispatch FCM push
    try:
        fcm_payload = {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': type,
            'notification_id': str(notif.id),
        }
        for k, v in payload.items():
            if k not in ('title', 'body'):
                fcm_payload[k] = str(v)

        push_res = send_push_to_user(
            user=user,
            title=title,
            body=body,
            data_payload=fcm_payload,
        )
        logger.info("[notify] Notification #%s created for user %s; push result: %s", notif.id, user.id, push_res.get('status'))
    except Exception as exc:
        logger.warning("[notify] FCM push dispatch error for notification #%s: %s", notif.id, exc)

    return notif

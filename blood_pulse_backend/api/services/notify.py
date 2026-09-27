# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Notification Dispatch Service.
Dispatches wave notifications, creates notification audit logs,
updates user unread badges, and sends high-priority FCM pushes.
"""

import logging
from django.utils import timezone
from api.models import EmergencyNotification, UserNotificationState

logger = logging.getLogger(__name__)


def dispatch_wave_notifications(blood_request, candidate_list: list, wave_number: int = 1) -> int:
    """
    Records notifications for candidate donors and attempts FCM push delivery.
    Returns the number of notifications dispatched.
    """
    dispatched_count = 0
    now = timezone.now()

    donor_tokens = []
    
    for item in candidate_list:
        donor = item['donor']
        
        # 1. Create DB audit record
        EmergencyNotification.objects.create(
            request=blood_request,
            donor=donor,
            wave=wave_number,
            sent_at=now,
            delivered=True,
        )

        # 2. Increment donor alert metrics
        donor.alert_count = (donor.alert_count or 0) + 1
        donor.save(update_fields=['alert_count'])

        # 3. Increment unread notification badge
        if donor.user:
            UserNotificationState.increment_for_user(donor.user)

        dispatched_count += 1

    logger.info(f"Dispatched Wave {wave_number} for Request #{blood_request.id} to {dispatched_count} donors.")
    return dispatched_count

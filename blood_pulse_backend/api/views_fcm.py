# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import uuid
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from api.models import DonorProfile, UserDevice


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_fcm_view(request):
    """
    Registers or refreshes FCM device token tied to UserDevice (#36).
    Also syncs with DonorProfile if present.
    """
    token = request.data.get('token') or request.data.get('fcm_token')
    if not token or not str(token).strip():
        return Response({"error": "Token is required"}, status=status.HTTP_400_BAD_REQUEST)

    token = str(token).strip()
    device_id = request.data.get('device_id') or request.headers.get('X-Device-Id') or request.data.get('deviceId')
    platform = request.data.get('platform', 'android')
    device_name = request.data.get('device_name', '')

    # 1. Update or create UserDevice tied to this token
    if device_id:
        device, _ = UserDevice.objects.get_or_create(
            user=request.user,
            device_id=device_id,
            defaults={'platform': platform, 'device_name': device_name},
        )
    else:
        device = UserDevice.objects.filter(user=request.user, is_revoked=False).first()
        if not device:
            device = UserDevice.objects.create(
                user=request.user,
                device_id=f"device_{uuid.uuid4().hex[:12]}",
                platform=platform,
                device_name=device_name,
            )

    device.fcm_token = token
    device.fcm_updated_at = timezone.now()
    device.is_revoked = False
    if device_name and not device.device_name:
        device.device_name = device_name
    device.save(update_fields=['fcm_token', 'fcm_updated_at', 'is_revoked', 'device_name'])

    # 2. Also sync to DonorProfile if user is a donor
    DonorProfile.objects.filter(user=request.user).update(fcm_token=token)

    return Response({
        "status": "success",
        "token": token,
        "device_id": device.device_id,
    }, status=status.HTTP_200_OK)

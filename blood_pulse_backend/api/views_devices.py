# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from api.models import UserDevice


class UserDeviceListAPIView(APIView):
    """
    GET /api/account/devices/
    Lists all registered devices and sessions for the authenticated user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        current_device_id = (
            request.headers.get('X-Device-ID') or
            request.META.get('HTTP_X_DEVICE_ID', '')
        )
        devices = UserDevice.objects.filter(user=request.user).order_by('-last_seen')
        data = []
        for d in devices:
            data.append({
                'id': d.id,
                'device_id': d.device_id,
                'device_name': d.device_name or 'Mobile Device',
                'platform': d.platform,
                'first_seen': d.first_seen.isoformat(),
                'last_seen': d.last_seen.isoformat(),
                'last_ip_masked': d.last_ip_masked,
                'last_city_approx': d.last_city_approx,
                'is_revoked': d.is_revoked,
                'is_current': bool(current_device_id and d.device_id == current_device_id),
            })
        return Response({'devices': data}, status=status.HTTP_200_OK)


class UserDeviceRevokeAPIView(APIView):
    """
    POST /api/account/devices/<int:pk>/revoke/
    Revokes a specific device session. Blocks IDOR (user can only revoke their own device).
    If revoking current device or refresh token is supplied, blacklists the refresh token.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        device = UserDevice.objects.filter(pk=pk).first()
        if not device:
            return Response({'error': 'Device not found.'}, status=status.HTTP_404_NOT_FOUND)

        if device.user != request.user:
            return Response({'error': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

        device.is_revoked = True
        device.save(update_fields=['is_revoked'])

        # Check if refresh token provided or current device revoked
        refresh_str = request.data.get('refresh')
        current_device_id = (
            request.headers.get('X-Device-ID') or
            request.META.get('HTTP_X_DEVICE_ID', '')
        )
        if refresh_str:
            token_obj = OutstandingToken.objects.filter(token=refresh_str, user=request.user).first()
            if token_obj:
                BlacklistedToken.objects.get_or_create(token=token_obj)
        elif current_device_id and device.device_id == current_device_id:
            # If current device is revoked without explicit refresh, blacklist all user's outstanding tokens
            for t in OutstandingToken.objects.filter(user=request.user):
                BlacklistedToken.objects.get_or_create(token=t)

        return Response({
            'message': 'Device successfully revoked.',
            'device_id': device.device_id,
            'is_revoked': True,
        }, status=status.HTTP_200_OK)


class UserLogoutAllDevicesAPIView(APIView):
    """
    POST /api/account/devices/logout-all/
    Revokes all device sessions and blacklists outstanding refresh tokens.
    Supports ?include_current=true/false (defaults to false).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        include_current = request.query_params.get('include_current', 'false').lower() in ('true', '1')
        current_device_id = (
            request.headers.get('X-Device-ID') or
            request.META.get('HTTP_X_DEVICE_ID', '')
        )

        devices_qs = UserDevice.objects.filter(user=request.user)
        if not include_current and current_device_id:
            devices_qs = devices_qs.exclude(device_id=current_device_id)

        revoked_count = devices_qs.update(is_revoked=True)

        current_refresh = request.data.get('refresh')
        outstanding = OutstandingToken.objects.filter(user=request.user)
        blacklisted_count = 0
        for token in outstanding:
            if not include_current and current_refresh and token.token == current_refresh:
                continue
            _, created = BlacklistedToken.objects.get_or_create(token=token)
            if created:
                blacklisted_count += 1

        return Response({
            'message': 'Device sessions revoked successfully.',
            'devices_revoked': revoked_count,
            'tokens_invalidated': blacklisted_count,
            'included_current': include_current,
        }, status=status.HTTP_200_OK)


class PasswordChangeAPIView(APIView):
    """
    POST /api/auth/password/change/
    Allows an authenticated user to change their password.
    Upon successful password change, revokes all other sessions/devices and blacklists tokens.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        old_password = request.data.get('old_password')
        new_password = request.data.get('new_password')

        if not old_password or not new_password:
            return Response(
                {'error': 'Both old_password and new_password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = request.user
        if not user.check_password(old_password):
            return Response(
                {'error': 'Current password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            validate_password(new_password, user=user)
        except ValidationError as e:
            return Response(
                {'errors': {'new_password': list(e.messages)}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save()

        current_device_id = (
            request.headers.get('X-Device-ID') or
            request.META.get('HTTP_X_DEVICE_ID', '')
        )

        # Revoke other devices
        devices_qs = UserDevice.objects.filter(user=user)
        if current_device_id:
            devices_qs.exclude(device_id=current_device_id).update(is_revoked=True)
        else:
            devices_qs.update(is_revoked=True)

        # Blacklist all outstanding tokens except current refresh token if provided
        current_refresh = request.data.get('refresh')
        outstanding = OutstandingToken.objects.filter(user=user)
        for token in outstanding:
            if current_refresh and token.token == current_refresh:
                continue
            BlacklistedToken.objects.get_or_create(token=token)

        return Response({
            'message': 'Password changed successfully. Other sessions have been revoked.',
        }, status=status.HTTP_200_OK)

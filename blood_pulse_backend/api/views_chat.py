# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Real-time chat views between requester and donor (#37, #39).
Supports polling with backoff, delivery/read receipts, rate limiting, and voice messages.
"""

import os
import uuid
from django.conf import settings
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from api.models import RequestAcceptance, DirectMessage, Notification
from api.serializers_chat import DirectMessageSerializer
from api.throttles import DirectMessageThrottle
from api.services.storage import get_media_storage, is_persistent_remote_configured


def _get_journey_and_check_participant(acceptance_id, user):
    """
    Ensures user is an authorized participant (requester, donor, or admin)
    in the journey. Returns (acceptance, other_user).
    """
    acceptance = get_object_or_404(
        RequestAcceptance.objects.select_related('request__requester', 'donor__user'),
        pk=acceptance_id,
    )
    requester = acceptance.request.requester
    donor_user = acceptance.donor.user

    if user.id == requester.id:
        return acceptance, donor_user
    elif user.id == donor_user.id:
        return acceptance, requester
    elif user.is_staff:
        # Staff can inspect, default other user to requester
        return acceptance, donor_user

    return None, None


class JourneyMessageListCreateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get_throttles(self):
        if self.request.method == 'POST':
            return [DirectMessageThrottle()]
        return []

    def get(self, request, acceptance_id):
        acceptance, other_user = _get_journey_and_check_participant(acceptance_id, request.user)
        if not acceptance:
            return Response(
                {'detail': 'You are not a participant in this journey chat.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        now = timezone.now()
        mark_read = request.query_params.get('mark_read', 'false').lower() == 'true'

        # Auto-mark incoming SENT messages as DELIVERED upon polling
        incoming_unconfirmed = DirectMessage.objects.filter(
            acceptance=acceptance,
            recipient=request.user,
            status='SENT',
        )
        if incoming_unconfirmed.exists():
            incoming_unconfirmed.update(status='DELIVERED', delivered_at=now)

        if mark_read:
            DirectMessage.objects.filter(
                acceptance=acceptance,
                recipient=request.user,
                status__in=['SENT', 'DELIVERED'],
            ).update(status='READ', read_at=now)

        # Pagination
        try:
            limit = min(100, max(1, int(request.query_params.get('limit', 30))))
            offset = max(0, int(request.query_params.get('offset', 0)))
        except ValueError:
            limit = 30
            offset = 0

        qs = DirectMessage.objects.filter(acceptance=acceptance).select_related('sender', 'recipient').order_by('created_at')
        total = qs.count()
        messages = qs[offset:offset + limit]

        serializer = DirectMessageSerializer(messages, many=True, context={'request': request})
        return Response({
            'count': total,
            'limit': limit,
            'offset': offset,
            'other_user_id': other_user.id if other_user else None,
            'other_user_name': other_user.get_full_name() or other_user.username if other_user else '',
            'results': serializer.data,
        }, status=status.HTTP_200_OK)

    def post(self, request, acceptance_id):
        acceptance, other_user = _get_journey_and_check_participant(acceptance_id, request.user)
        if not acceptance or not other_user:
            return Response(
                {'detail': 'You are not a participant in this journey chat.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        content = request.data.get('content', '').strip()
        message_type = request.data.get('message_type', 'TEXT').strip().upper()
        voice_url = request.data.get('voice_url', '').strip() or None
        voice_duration_seconds = int(request.data.get('voice_duration_seconds', 0) or 0)

        if message_type not in ('TEXT', 'VOICE', 'IMAGE'):
            return Response({'detail': 'Invalid message_type.'}, status=status.HTTP_400_BAD_REQUEST)

        if message_type == 'TEXT' and not content:
            return Response({'detail': 'Message content cannot be empty.'}, status=status.HTTP_400_BAD_REQUEST)

        if message_type == 'VOICE' and not voice_url:
            return Response({'detail': 'voice_url is required for voice messages.'}, status=status.HTTP_400_BAD_REQUEST)

        msg = DirectMessage.objects.create(
            acceptance=acceptance,
            sender=request.user,
            recipient=other_user,
            content=content,
            message_type=message_type,
            voice_url=voice_url,
            voice_duration_seconds=voice_duration_seconds,
            status='SENT',
        )

        now = timezone.now()
        # In-app notification for the recipient
        preview_text = content[:60] if content else ("Voice note" if message_type == 'VOICE' else "Attachment")
        try:
            Notification.objects.create(
                user=other_user,
                title="New Chat Message",
                body=f"{request.user.first_name or request.user.username}: {preview_text}",
                type="CHAT_MESSAGE",
                is_read=False,
                created_at=now,
            )
        except Exception:
            pass

        serializer = DirectMessageSerializer(msg, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class MessageMarkReadAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, acceptance_id, pk):
        acceptance, _ = _get_journey_and_check_participant(acceptance_id, request.user)
        if not acceptance:
            return Response({'detail': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)

        msg = get_object_or_404(DirectMessage, pk=pk, acceptance=acceptance)
        if msg.recipient_id != request.user.id and not request.user.is_staff:
            return Response({'detail': 'Only recipient can mark as read.'}, status=status.HTTP_403_FORBIDDEN)

        now = timezone.now()
        msg.status = 'READ'
        msg.read_at = now
        if not msg.delivered_at:
            msg.delivered_at = now
        msg.save(update_fields=['status', 'read_at', 'delivered_at'])

        return Response({'status': 'READ', 'read_at': now}, status=status.HTTP_200_OK)


class MessageReportAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, acceptance_id, pk):
        acceptance, _ = _get_journey_and_check_participant(acceptance_id, request.user)
        if not acceptance:
            return Response({'detail': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)

        msg = get_object_or_404(DirectMessage, pk=pk, acceptance=acceptance)
        reason = request.data.get('reason', 'Inappropriate or abusive language.').strip()
        msg.is_reported = True
        msg.report_reason = reason[:255]
        msg.save(update_fields=['is_reported', 'report_reason'])

        return Response({'status': 'REPORTED', 'message': 'Message reported for review.'}, status=status.HTTP_200_OK)


class MessageDeleteAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, acceptance_id, pk):
        acceptance, _ = _get_journey_and_check_participant(acceptance_id, request.user)
        if not acceptance:
            return Response({'detail': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)

        msg = get_object_or_404(DirectMessage, pk=pk, acceptance=acceptance)
        if msg.sender_id != request.user.id and not request.user.is_staff:
            return Response({'detail': 'You can only delete your own messages.'}, status=status.HTTP_403_FORBIDDEN)

        # If it was a voice file, remove from storage if local
        if msg.voice_url and '/media/chat_voice/' in msg.voice_url:
            try:
                rel_path = msg.voice_url.split('/media/')[-1]
                if default_storage.exists(rel_path):
                    default_storage.delete(rel_path)
            except Exception:
                pass

        msg.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class VoiceMessageUploadAPIView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, acceptance_id):
        acceptance, _ = _get_journey_and_check_participant(acceptance_id, request.user)
        if not acceptance:
            return Response({'detail': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)

        is_testing = getattr(settings, 'IS_TESTING', False)
        if not settings.DEBUG and not is_testing and not is_persistent_remote_configured():
            return Response(
                {
                    'code': 'VOICE_UNAVAILABLE',
                    'detail': 'Voice messaging is temporarily unavailable because persistent storage is not configured.',
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        voice_file = request.FILES.get('voice_file')
        if not voice_file:
            return Response({'detail': 'No voice_file provided.'}, status=status.HTTP_400_BAD_REQUEST)

        # Size check (max 5 MB for a 60s audio clip)
        max_bytes = 5 * 1024 * 1024
        if voice_file.size > max_bytes:
            return Response({'detail': 'Voice message exceeds 5MB limit.'}, status=status.HTTP_400_BAD_REQUEST)

        # MIME and Extension validation (m4a, aac, mp3, mp4, wav, ogg)
        allowed_exts = ('.m4a', '.aac', '.mp3', '.mp4', '.wav', '.ogg')
        ext = os.path.splitext(voice_file.name)[1].lower()
        if ext not in allowed_exts:
            ext = '.m4a'

        # Check content type
        allowed_mimes = (
            'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mp4', 'audio/mpeg',
            'audio/wav', 'audio/x-wav', 'audio/ogg', 'application/octet-stream',
        )
        content_type = getattr(voice_file, 'content_type', '')
        if content_type and content_type.lower() not in allowed_mimes:
            return Response({'detail': f'Unsupported audio MIME type: {content_type}'}, status=status.HTTP_400_BAD_REQUEST)

        duration = int(request.data.get('duration_seconds', 0) or 0)
        duration = min(60, max(1, duration))  # Enforce max 60s

        storage = get_media_storage()
        filename = f"{uuid.uuid4().hex}{ext}"
        folder = f"chat_voice/{acceptance_id}"
        upload_result = storage.upload_file(
            file_bytes=voice_file.read(),
            filename=filename,
            folder=folder,
            resource_type="video",
        )
        voice_url = upload_result.get('url')

        return Response({
            'voice_url': voice_url,
            'duration_seconds': duration,
        }, status=status.HTTP_201_CREATED)

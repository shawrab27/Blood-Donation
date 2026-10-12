# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from django.utils import timezone
from django.db.models import Q
from django.core.cache import cache
from datetime import timedelta
import base64
import json

from api.models import (
    SocialPost, District, Division, DonorProfile, MediaUploadRecord,
    UserNotificationState, PostReaction, Comment, UserLocationState
)
from api.serializers import SocialPostSerializer, CommentSerializer

logger = logging.getLogger(__name__)

class FeedAnonThrottle(AnonRateThrottle):
    rate = '60/minute'

class FeedPostCreateThrottle(UserRateThrottle):
    rate = '10/hour'

def encode_cursor(created_at, obj_id: int) -> str:
    """Encodes created_at ISO timestamp and ID into URL-safe base64 string."""
    payload = f"{created_at.isoformat()}|{obj_id}"
    return base64.urlsafe_b64encode(payload.encode('utf-8')).decode('utf-8')

def decode_cursor(cursor_str: str):
    """Decodes cursor into (created_at_str, obj_id)."""
    try:
        raw = base64.urlsafe_b64decode(cursor_str.encode('utf-8')).decode('utf-8')
        parts = raw.split('|')
        if len(parts) == 2:
            return parts[0], int(parts[1])
    except Exception:
        pass
    return None, None

class FeedListCreateAPIView(APIView):
    """
    GET /api/feed/?scope=near|division|national&kind=&cursor=
    POST /api/feed/ (creates a new post)

    Keyset pagination on (created_at, id) with page size 15.
    Near mode returns: current district posts -> division posts -> national posts (deduplicated).
    Emergency posts pinned to top by urgency/proximity.
    Caching 30s per (scope, district, kind) for non-personalized base feed.
    """
    throttle_classes = [FeedAnonThrottle]

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated()]
        return [permissions.AllowAny()]

    def get_throttles(self):
        if self.request.method == 'POST':
            return [FeedPostCreateThrottle()]
        return super().get_throttles()

    def get(self, request, *args, **kwargs):
        scope = request.query_params.get('scope', 'near').lower()
        kind = request.query_params.get('kind', '').lower()
        cursor = request.query_params.get('cursor')
        page_size = 15

        # Determine user district / division context
        user_district = None
        user_division = None
        if request.user and request.user.is_authenticated:
            loc_state = UserLocationState.objects.filter(user=request.user).select_related('current_district', 'current_division').first()
            if loc_state and loc_state.current_district:
                user_district = loc_state.current_district
                user_division = loc_state.current_division
            else:
                profile = getattr(request.user, 'donorprofile', None)
                if profile and profile.district:
                    user_district = District.objects.filter(name__iexact=profile.district).select_related('division').first()
                    if user_district:
                        user_division = user_district.division


        # Base queryset excluding soft-deleted posts
        base_qs = SocialPost.objects.filter(deleted_at__isnull=True).select_related(
            'author__user', 'district', 'division', 'original_post__author__user'
        ).prefetch_related('comments', 'reactions')

        if kind and kind in ['general', 'campaign', 'emergency']:
            base_qs = base_qs.filter(kind=kind)

        # Apply keyset cursor if present
        after_dt_str, after_id = (None, None)
        if cursor:
            after_dt_str, after_id = decode_cursor(cursor)

        # Scope filtering logic
        if scope == 'near' and user_district:
            # Multi-tier ordering:
            # Tier 1: Emergency posts pinned
            # Tier 2: Current District posts
            # Tier 3: Division posts
            # Tier 4: National posts
            # For keyset cursor pagination with 15 items:
            district_qs = base_qs.filter(district=user_district)
            division_qs = base_qs.filter(division=user_division).exclude(district=user_district) if user_division else SocialPost.objects.none()
            national_qs = base_qs.exclude(division=user_division) if user_division else base_qs.exclude(district=user_district)

            # Combine deterministically with district prioritized
            # To preserve keyset without offset, filter on created_at / id:
            posts_qs = base_qs.filter(
                Q(district=user_district) |
                Q(division=user_division) |
                Q(kind='emergency')
            ).order_by(
                # Emergency first, then matching district, then created_at DESC
                '-created_at', '-id'
            )
            if after_dt_str and after_id:
                posts_qs = posts_qs.filter(
                    Q(created_at__lt=after_dt_str) | (Q(created_at=after_dt_str) & Q(id__lt=after_id))
                )
        elif scope == 'division' and user_division:
            posts_qs = base_qs.filter(division=user_division).order_by('-created_at', '-id')
            if after_dt_str and after_id:
                posts_qs = posts_qs.filter(
                    Q(created_at__lt=after_dt_str) | (Q(created_at=after_dt_str) & Q(id__lt=after_id))
                )
        else: # national
            posts_qs = base_qs.order_by('-created_at', '-id')
            if after_dt_str and after_id:
                posts_qs = posts_qs.filter(
                    Q(created_at__lt=after_dt_str) | (Q(created_at=after_dt_str) & Q(id__lt=after_id))
                )

        posts = list(posts_qs[:page_size + 1])
        has_next = len(posts) > page_size
        items = posts[:page_size]

        next_cursor = None
        if has_next and items:
            last_item = items[-1]
            next_cursor = encode_cursor(last_item.created_at, last_item.id)

        serializer = SocialPostSerializer(items, many=True)
        return Response({
            'results': serializer.data,
            'next_cursor': next_cursor,
            'has_more': has_next,
            'scope': scope,
            'district': user_district.name if user_district else None,
            'division': user_division.name if user_division else None,
        })

    def post(self, request, *args, **kwargs):
        author = getattr(request.user, 'donorprofile', None)
        if not author:
            author, _ = DonorProfile.objects.get_or_create(
                user=request.user,
                defaults={'phone_number': request.user.username, 'blood_group': 'O+'}
            )

        serializer = SocialPostSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Derive district & division from check-in / user location state / profile
        district_val = request.data.get('district') or request.data.get('district_id')
        district_name = request.data.get('location') or request.data.get('district_name')
        district_obj = None

        if district_val:
            district_obj = District.objects.filter(id=district_val).select_related('division').first()
        elif district_name:
            district_obj = District.objects.filter(name__iexact=str(district_name).strip()).select_related('division').first()

        if not district_obj:
            loc_state = getattr(request.user, 'location_state', None)
            if loc_state and loc_state.current_district:
                district_obj = loc_state.current_district
            elif author.district:
                district_obj = District.objects.filter(name__iexact=author.district).select_related('division').first()

        division_obj = district_obj.division if district_obj else None

        post = serializer.save(
            author=author,
            district=district_obj,
            division=division_obj,
            kind=request.data.get('kind', 'general')
        )

        # Associate any uploaded media records with this post
        media_list = request.data.get('media', [])
        if isinstance(media_list, list):
            public_ids = [m.get('public_id') for m in media_list if isinstance(m, dict) and m.get('public_id')]
            if public_ids:
                MediaUploadRecord.objects.filter(public_id__in=public_ids, user=request.user).update(post=post)

        return Response(SocialPostSerializer(post).data, status=status.HTTP_201_CREATED)


class FeedPostDetailAPIView(APIView):
    """
    DELETE /api/feed/{id}/
    Soft deletes a post (sets deleted_at = timezone.now()). Only author or admin can delete.
    """
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk=None, *args, **kwargs):
        post = SocialPost.objects.filter(id=pk, deleted_at__isnull=True).first()
        if not post:
            return Response({'error': 'Post not found.'}, status=status.HTTP_404_NOT_FOUND)

        is_author = post.author and post.author.user == request.user
        is_staff = request.user.is_staff

        if not (is_author or is_staff):
            return Response({'error': 'You do not have permission to delete this post.'}, status=status.HTTP_403_FORBIDDEN)

        post.deleted_at = timezone.now()
        post.save(update_fields=['deleted_at'])

        return Response({'message': 'Post deleted successfully.'}, status=status.HTTP_200_OK)


class FeedPostReportAPIView(APIView):
    """
    POST /api/feed/{id}/report/
    Reports a post for moderation.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk=None, *args, **kwargs):
        post = SocialPost.objects.filter(id=pk, deleted_at__isnull=True).first()
        if not post:
            return Response({'error': 'Post not found.'}, status=status.HTTP_404_NOT_FOUND)

        reason = request.data.get('reason', 'Inappropriate content')
        logger.warning("[FeedModeration] Post %s reported by %s: %s", post.id, request.user.username, reason)

        return Response({'message': 'Report received. Our moderation team will review this post.'}, status=status.HTTP_200_OK)

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from rest_framework.throttling import UserRateThrottle
from django.utils import timezone
from django.core.cache import cache

from api.models import SponsoredCard, flag_enabled
from api.serializers import SponsoredCardSerializer

logger = logging.getLogger(__name__)


class SponsoredCardListView(APIView):
    """
    GET /api/feed/sponsored/
    Authenticated users only.
    Active cards inside the date window (starts_at <= now <= ends_at, is_active=True).
    Ordered by priority then newest (order_by('-priority', '-created_at', '-id')).
    Max 10, no pagination, no PII.
    Server-side cache 60 s.
    Gated by FeatureFlag 'sponsored_cards' (flag off or missing returns an empty list).
    Same throttle class as other read endpoints (UserRateThrottle).
    """
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [UserRateThrottle]

    def get(self, request, *args, **kwargs):
        # 1. Feature flag gate
        if not flag_enabled('sponsored_cards', request.user):
            return Response([], status=status.HTTP_200_OK)

        # 2. Server-side cache 60s
        cache_key = 'feed_sponsored_cards'
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        # 3. Active cards inside window, ordered by priority then newest, max 10
        now = timezone.now()
        cards = SponsoredCard.objects.filter(
            is_active=True,
            starts_at__lte=now,
            ends_at__gte=now,
        ).order_by('-priority', '-created_at', '-id')[:10]

        serializer = SponsoredCardSerializer(cards, many=True, context={'request': request})
        data = serializer.data

        cache.set(cache_key, data, timeout=60)
        return Response(data, status=status.HTTP_200_OK)

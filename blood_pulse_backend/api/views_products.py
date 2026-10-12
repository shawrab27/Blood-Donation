# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from django.core.cache import cache
from django.db.models import Q
from .models import Product
from .serializers import ProductSerializer


class ProductViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Public Products API for Blood Accessories & Clinical Supplies.
    GET /api/products/?tier=&q=&cursor=
    Returns active items with pre-fetched images.
    Caches responses for 60 seconds to ensure high performance.
    """
    permission_classes = [permissions.AllowAny]
    serializer_class = ProductSerializer

    def get_queryset(self):
        qs = Product.objects.filter(is_active=True).prefetch_related('images').order_by('sort_order', '-created_at')

        tier = self.request.query_params.get('tier')
        if tier is not None and str(tier).isdigit():
            qs = qs.filter(tier=int(tier))

        q = self.request.query_params.get('q')
        if q:
            q_clean = q.strip()
            qs = qs.filter(
                Q(name__icontains=q_clean) |
                Q(description__icontains=q_clean) |
                Q(store_name__icontains=q_clean)
            )

        return qs

    def list(self, request, *args, **kwargs):
        tier = request.query_params.get('tier', 'all')
        q = request.query_params.get('q', '').strip()
        cursor = request.query_params.get('cursor', '')
        page = request.query_params.get('page', '1')

        cache_key = f"products_list_t{tier}_q{q}_c{cursor}_p{page}"
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        response_data = {
            'count': queryset.count(),
            'results': serializer.data,
        }

        # Cache for 60 seconds
        cache.set(cache_key, response_data, 60)
        return Response(response_data, status=status.HTTP_200_OK)

    def retrieve(self, request, *args, **kwargs):
        product_id = kwargs.get('pk')
        cache_key = f"product_detail_{product_id}"
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            return Response(cached_data, status=status.HTTP_200_OK)

        instance = self.get_object()
        serializer = self.get_serializer(instance)
        cache.set(cache_key, serializer.data, 60)
        return Response(serializer.data, status=status.HTTP_200_OK)

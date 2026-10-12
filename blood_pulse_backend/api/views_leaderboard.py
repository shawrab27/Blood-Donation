# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework import status
from django.core.cache import cache
from api.models import DonorProfile


class LeaderboardAPIView(APIView):
    """
    GET /api/leaderboard/?scope=national|division|district&limit=5
    Real Top Donors Leaderboard:
    - Counts only verified completed donations (total_bags_donated > 0).
    - Window / ranked sort cached for 5 minutes.
    - Privacy: Shows "FirstName L." only if public_profile=True consented; otherwise "Anonymous Hero".
    - User with 0 donations is displayed as "Unranked".
    - No mock names, fake counts, or fabricated ratings.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        scope = request.query_params.get('scope', 'national').lower()
        division = request.query_params.get('division', '').strip()
        district = request.query_params.get('district', '').strip()
        limit_str = request.query_params.get('limit', '5')
        try:
            limit = max(1, min(50, int(limit_str)))
        except ValueError:
            limit = 5

        cache_key = f"leaderboard_v2_{scope}_{division}_{district}_{limit}"
        cached_data = cache.get(cache_key)

        if cached_data is None:
            qs = DonorProfile.objects.filter(total_bags_donated__gt=0, is_suspended=False)
            if scope == 'division' and division:
                qs = qs.filter(district__iexact=division)  # or division check
            elif scope == 'district' and district:
                qs = qs.filter(district__iexact=district)

            # Order strictly by completed donations descending
            top_donors = qs.select_related('user').order_by('-total_bags_donated', '-last_active_at', 'id')[:limit]

            donors_list = []
            for idx, d in enumerate(top_donors, start=1):
                if d.public_profile and d.user:
                    first = d.user.first_name or d.google_display_name or "Donor"
                    initial = f" {d.user.last_name[0]}." if d.user.last_name else ""
                    name = f"{first}{initial}".strip()
                    avatar = d.profile_picture.url if d.profile_picture else d.google_photo_url
                else:
                    name = "Anonymous Hero"
                    avatar = None

                donors_list.append({
                    "rank": idx,
                    "id": d.id,
                    "name": name,
                    "blood_group": d.blood_group,
                    "donations_count": d.total_bags_donated,
                    "district": d.district,
                    "badge": d.badge,
                    "avatar_url": avatar,
                    "is_consented": d.public_profile,
                })

            cached_data = {
                "scope": scope,
                "top_donors": donors_list,
                "total_ranked_donors": qs.count(),
            }
            cache.set(cache_key, cached_data, timeout=300)

        # Include personal rank for the authenticated viewer
        response_data = dict(cached_data)
        if request.user and request.user.is_authenticated:
            user_profile = DonorProfile.objects.filter(user=request.user).first()
            if user_profile and user_profile.verified_donations_count > 0:
                response_data["my_rank"] = user_profile.global_rank
                response_data["my_donations"] = user_profile.verified_donations_count
            else:
                response_data["my_rank"] = "Unranked"
                response_data["my_donations"] = 0
        else:
            response_data["my_rank"] = None
            response_data["my_donations"] = 0

        return Response(response_data, status=status.HTTP_200_OK)

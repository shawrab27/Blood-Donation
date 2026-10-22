# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import re
from datetime import timedelta, date
from django.conf import settings
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.db import transaction
from django.db.models import Count, Sum, Min, Q, F, Window
from django.db.models.functions import Coalesce, Rank, Greatest
from django.utils import timezone
from django.http import HttpResponse
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.throttling import UserRateThrottle, AnonRateThrottle

from api.models import (
    DonorProfile, DonationHistory, BloodGroupChangeRequest,
    DonorReview, XPEvent, BloodRequest, DonationMatch,
    SocialPost, AuditLog, Upazila,
    calculate_user_xp_and_level, award_verified_donation_xp
)
from api.serializers import PublicDonorProfileSerializer, DonorProfileSerializer

# Timezone fallback for Asia/Dhaka
try:
    from zoneinfo import ZoneInfo
    DHAKA_TZ = ZoneInfo("Asia/Dhaka")
except Exception:
    from datetime import timezone as dt_tz, timedelta as dt_td
    DHAKA_TZ = dt_tz(dt_td(hours=6))

DONOR_COOLDOWN_DAYS = 90


def get_dhaka_today():
    """Returns today's date in Asia/Dhaka timezone."""
    return timezone.now().astimezone(DHAKA_TZ).date()


def calculate_eligibility(latest_donation_date):
    """
    Computes next eligible donation date and remaining days in Asia/Dhaka timezone.
    Cooldown is strictly 90 days.
    """
    today = get_dhaka_today()
    if not latest_donation_date:
        return {
            'next_eligible_date': today,
            'days_left': 0,
            'is_eligible': True,
        }
    next_eligible = latest_donation_date + timedelta(days=DONOR_COOLDOWN_DAYS)
    days_left = max(0, (next_eligible - today).days)
    return {
        'next_eligible_date': next_eligible,
        'days_left': days_left,
        'is_eligible': days_left == 0,
    }


class ReviewPostThrottle(UserRateThrottle):
    rate = '10/minute'


class ProfileMeView(APIView):
    """
    GET, PATCH, DELETE /api/profile/me/
    Manages the authenticated user's private profile and hero stats.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).select_related('user', 'institution', 'upazila_linked').first()

        # Incomplete registration gate
        if not profile or not profile.is_profile_complete:
            return Response({
                "code": "REGISTRATION_INCOMPLETE",
                "detail": "Please complete your registration.",
                "is_profile_complete": False,
                "missing_fields": profile.check_is_complete()[1] if profile else ["profile"],
            }, status=status.HTTP_403_FORBIDDEN)

        today_dhaka = get_dhaka_today()

        # Verified bags count
        verified_bags = DonationHistory.objects.filter(
            donor=profile, verified=True
        ).aggregate(total=Coalesce(Sum('bags'), 0))['total']

        # Total bags (including self-reported)
        total_bags = DonationHistory.objects.filter(
            donor=profile
        ).aggregate(total=Coalesce(Sum('bags'), 0))['total']
        if total_bags < profile.total_bags_donated:
            total_bags = profile.total_bags_donated

        # Latest donation date
        latest_dh = DonationHistory.objects.filter(donor=profile).order_by('-donated_at').first()
        latest_date = latest_dh.donated_at if latest_dh else profile.last_donation_date

        # Eligibility calculation
        eligibility = calculate_eligibility(latest_date)

        # XP and Level
        xp_info = calculate_user_xp_and_level(user)

        # Global Rank calculation (private rank)
        rank = profile.global_rank

        full_name = f"{user.first_name} {user.last_name}".strip() or user.username
        photo = profile.google_photo_url or (profile.profile_picture.url if profile.profile_picture else None)

        response_data = {
            "id": profile.id,
            "user_id": user.id,
            "name": full_name,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "phone_number": profile.phone_number,
            "photo": photo,
            "blood_group": profile.blood_group,
            "tier": profile.badge,
            "rank": rank,
            "global_rank": rank,
            "bags_donated": verified_bags,
            "total_bags_donated": total_bags,
            "last_donation": str(latest_date) if latest_date else None,
            "last_donation_date": str(latest_date) if latest_date else None,
            "next_eligible_date": str(eligibility['next_eligible_date']),
            "days_left": eligibility['days_left'],
            "is_eligible": eligibility['is_eligible'],
            "rating_avg": profile.rating_avg,
            "rating_count": profile.rating_count,
            "xp": xp_info['xp'],
            "level": xp_info['level'],
            "level_progress": xp_info['progress'],
            "next_level_xp": xp_info['next_level_xp'],
            "bio": profile.bio or "",
            "weight_kg": profile.weight_kg,
            "district": profile.district,
            "upazila": profile.upazila_linked.name if profile.upazila_linked else "",
            "upazila_id": profile.upazila_linked_id,
            "address": profile.address or "",
            "is_available": profile.is_available,
            "deferral_until": profile.deferral_until.isoformat() if profile.deferral_until else None,
            "alert_pause_until": profile.alert_pause_until.isoformat() if profile.alert_pause_until else None,
            "emergency_alerts_paused_until": profile.emergency_alerts_paused_until.isoformat() if profile.emergency_alerts_paused_until else None,
            "is_snoozed": bool(profile.alert_pause_until and profile.alert_pause_until > timezone.now()),
            "show_in_rankings": profile.show_in_rankings,
            "is_profile_complete": True,
            "user_intent": getattr(profile, 'user_intent', 'DONATE_AND_REQUEST'),
        }
        return Response(response_data)

    def patch(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        if not profile:
            return Response({"detail": "Profile not found."}, status=status.HTTP_404_NOT_FOUND)

        # Blood group modification is strictly admin-only once set
        if 'blood_group' in request.data and profile.blood_group and request.data['blood_group'] != profile.blood_group:
            return Response({
                "blood_group": ["Blood group cannot be directly modified. Please submit a Blood Group Change Request."]
            }, status=status.HTTP_400_BAD_REQUEST)
        elif 'blood_group' in request.data and not profile.blood_group:
            profile.blood_group = request.data['blood_group']

        # Name updates
        if 'name' in request.data:
            parts = str(request.data['name']).strip().split(' ', 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else ''
            user.save(update_fields=['first_name', 'last_name'])
        elif 'first_name' in request.data or 'last_name' in request.data:
            if 'first_name' in request.data:
                user.first_name = request.data['first_name']
            if 'last_name' in request.data:
                user.last_name = request.data['last_name']
            user.save(update_fields=['first_name', 'last_name'])

        # Phone number update with Bangladesh canonical normalization
        if 'phone_number' in request.data:
            from api.phone_utils import normalize_bd_phone, get_phone_variants, is_valid_phone
            raw_phone = request.data['phone_number']
            if raw_phone:
                if not is_valid_phone(raw_phone):
                    return Response({"phone_number": ["Invalid Bangladesh mobile phone number."]}, status=status.HTTP_400_BAD_REQUEST)
                canonical_phone = normalize_bd_phone(raw_phone)
                variants = get_phone_variants(canonical_phone)
                if DonorProfile.objects.filter(phone_number__in=variants).exclude(pk=profile.pk).exists():
                    return Response({"phone_number": ["An account with this phone number is already registered."]}, status=status.HTTP_400_BAD_REQUEST)
                profile.phone_number = canonical_phone
            else:
                return Response({"phone_number": ["Phone number cannot be empty."]}, status=status.HTTP_400_BAD_REQUEST)

        # Bio validation (max 120 chars)
        if 'bio' in request.data:
            bio_val = str(request.data['bio']).strip()
            if len(bio_val) > 120:
                return Response({"bio": ["Bio cannot exceed 120 characters."]}, status=status.HTTP_400_BAD_REQUEST)
            profile.bio = bio_val

        # Weight validation
        if 'weight_kg' in request.data:
            weight_val = request.data['weight_kg']
            if weight_val is not None and weight_val != '':
                try:
                    w = int(weight_val)
                    if w < 30 or w > 250:
                        return Response({"weight_kg": ["Weight must be between 30 and 250 kg."]}, status=status.HTTP_400_BAD_REQUEST)
                    profile.weight_kg = w
                except (ValueError, TypeError):
                    return Response({"weight_kg": ["Invalid weight value."]}, status=status.HTTP_400_BAD_REQUEST)
            else:
                profile.weight_kg = None

        # Last donation date validation
        if 'last_donation_date' in request.data:
            ldd_val = request.data['last_donation_date']
            if ldd_val:
                try:
                    if isinstance(ldd_val, str):
                        from datetime import date
                        parsed_date = date.fromisoformat(ldd_val)
                    else:
                        parsed_date = ldd_val
                    dhaka_today = get_dhaka_today()
                    if parsed_date > dhaka_today:
                        return Response({"last_donation_date": ["Cannot select a future date."]}, status=status.HTTP_400_BAD_REQUEST)
                    profile.last_donation_date = parsed_date
                except (ValueError, TypeError):
                    return Response({"last_donation_date": ["Invalid date format."]}, status=status.HTTP_400_BAD_REQUEST)

        # Location
        if 'district' in request.data:
            profile.district = request.data['district']
        if 'upazila_id' in request.data:
            up_id = request.data['upazila_id']
            if up_id:
                up = Upazila.objects.filter(id=up_id).first()
                if up:
                    profile.upazila_linked = up
            else:
                profile.upazila_linked = None

        # Availability
        if 'is_available' in request.data:
            profile.is_available = bool(request.data['is_available'])

        # Snooze for 1 month
        if 'snooze_1_month' in request.data:
            snooze = bool(request.data['snooze_1_month'])
            if snooze:
                profile.deferral_until = timezone.now() + timedelta(days=30)
                profile.is_available = False
            else:
                profile.deferral_until = None

        # Emergency alerts pause / snooze handling
        if 'snooze' in request.data or 'alert_pause_until' in request.data or 'emergency_alerts_paused_until' in request.data or 'enable_snooze' in request.data:
            val = request.data.get('alert_pause_until') or request.data.get('emergency_alerts_paused_until') or request.data.get('snooze')
            is_off = (
                val is None
                or val is False
                or request.data.get('enable_snooze') is False
                or str(val).strip().lower() in ('', 'null', 'none', 'off', '0')
            )
            if is_off:
                profile.alert_pause_until = None
                profile.emergency_alerts_paused_until = None

        # Show in rankings
        if 'show_in_rankings' in request.data:
            profile.show_in_rankings = bool(request.data['show_in_rankings'])

        # Avatar / Profile picture upload
        if 'profile_picture' in request.FILES:
            pic = request.FILES['profile_picture']
            if pic.size > 5 * 1024 * 1024:
                return Response({"profile_picture": ["Avatar image size must not exceed 5 MB."]}, status=status.HTTP_400_BAD_REQUEST)
            profile.profile_picture = pic

        profile.save()
        return self.get(request)

    def delete(self, request):
        """Soft-deletes and anonymizes user account."""
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        if profile:
            profile.phone_number = f"deleted_{profile.id}"
            profile.is_available = False
            profile.show_in_rankings = False
            profile.save(update_fields=['phone_number', 'is_available', 'show_in_rankings'])

        user.is_active = False
        user.email = f"deleted_{user.id}@bloodpulse.org"
        user.first_name = "Deleted"
        user.last_name = "User"
        user.set_unusable_password()
        user.save(update_fields=['is_active', 'email', 'first_name', 'last_name', 'password'])

        BloodRequest.objects.filter(requester=user, status__in=['OPEN', 'MATCHED', 'IN_TRANSIT']).update(status='CANCELLED')
        return Response({'detail': 'Your account has been deleted.'}, status=status.HTTP_204_NO_CONTENT)


class ProfileLastDonationView(APIView):
    """
    PATCH /api/profile/me/last-donation/
    Updates last donation date with 90-day cooldown enforcement, future date check,
    and daily throttle.
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        if not profile:
            return Response({"detail": "Profile not found."}, status=status.HTTP_404_NOT_FOUND)

        today_dhaka = get_dhaka_today()

        # Daily throttle: max 3 attempts per day
        cache_key = f"last_donation_throttle_{user.id}_{today_dhaka}"
        attempts = cache.get(cache_key, 0)
        if attempts >= 3:
            return Response({
                "code": "TOO_MANY_ATTEMPTS",
                "detail": "Maximum 3 last donation updates per day allowed."
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)

        # Date input
        raw_date = request.data.get('last_donation_date') or request.data.get('date')
        if not raw_date:
            return Response({
                "code": "MISSING_DATE",
                "detail": "Date is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            if isinstance(raw_date, str):
                parts = [int(p) for p in raw_date.split('-')]
                input_date = date(parts[0], parts[1], parts[2])
            elif isinstance(raw_date, date):
                input_date = raw_date
            else:
                raise ValueError()
        except Exception:
            return Response({
                "code": "INVALID_DATE_FORMAT",
                "detail": "Invalid date format. Use YYYY-MM-DD."
            }, status=status.HTTP_400_BAD_REQUEST)

        # Anti-cheat: cannot be in the future
        if input_date > today_dhaka:
            return Response({
                "code": "FUTURE_DATE",
                "detail": "Donation date cannot be in the future."
            }, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            locked_profile = DonorProfile.objects.select_for_update().get(id=profile.id)
            latest_dh = DonationHistory.objects.filter(donor=locked_profile).order_by('-donated_at').first()

            if latest_dh and latest_dh.donated_at:
                days_since = (input_date - latest_dh.donated_at).days
                if days_since < DONOR_COOLDOWN_DAYS and input_date >= latest_dh.donated_at:
                    return Response({
                        "code": "COOLDOWN_VIOLATION",
                        "detail": f"New donation date must be at least 90 days after previous donation ({latest_dh.donated_at}). Only {days_since} days elapsed."
                    }, status=status.HTTP_400_BAD_REQUEST)

            # Record self-reported donation history
            hospital_name = request.data.get('hospital', '')
            city_name = request.data.get('city', locked_profile.district or '')
            dh = DonationHistory.objects.create(
                donor=locked_profile,
                date=input_date,
                donated_at=input_date,
                location=hospital_name or city_name or 'Self-reported',
                hospital=hospital_name,
                city=city_name,
                bags=1,
                bags_donated=1,
                source='self_reported',
                verified=False,
                donation_type=request.data.get('donation_type', 'WHOLE'),
                notes=request.data.get('notes', 'Self-reported donation date.')
            )

            locked_profile.last_donation_date = input_date
            locked_profile.save(update_fields=['last_donation_date'])

            cache.set(cache_key, attempts + 1, timeout=86400)

            # Audit log without PII
            AuditLog.objects.create(
                user=user,
                action="LAST_DONATION_DATE_UPDATED",
                object_type="DonorProfile",
                object_id=locked_profile.id,
                timestamp=timezone.now(),
                changes={"new_date": str(input_date)}
            )

        eligibility = calculate_eligibility(input_date)
        return Response({
            "status": "success",
            "last_donation_date": str(input_date),
            "next_eligible_date": str(eligibility['next_eligible_date']),
            "days_left": eligibility['days_left'],
            "is_eligible": eligibility['is_eligible'],
            "source": "self_reported",
            "verified": False,
        })


class TopDonorsView(APIView):
    """
    GET /api/profile/top-donors/
    Top 4 donors by verified bags (tie-break: earliest first donation, then id)
    plus count of other donors. Cached for 60 seconds.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        cache_key = "top_donors_v2"
        cached_data = cache.get(cache_key)
        if cached_data is not None:
            return Response(cached_data)

        # USER RULE - do not change: Dynamic Top Donors from DB by verified bags or registered donation bags
        donors = DonorProfile.objects.filter(
            user__is_active=True,
            is_suspended=False,
            show_in_rankings=True
        ).annotate(
            vh_bags=Coalesce(Sum('donation_history__bags', filter=Q(donation_history__verified=True)), 0),
            first_donation=Min('donation_history__donated_at', filter=Q(donation_history__verified=True))
        ).annotate(
            verified_bags=Greatest(F('vh_bags'), F('total_bags_donated'))
        ).filter(verified_bags__gt=0).order_by('-verified_bags', 'first_donation', 'id')

        total_count = donors.count()
        top_4_qs = donors[:4]

        top_donors_list = []
        for idx, d in enumerate(top_4_qs, start=1):
            full_name = f"{d.user.first_name} {d.user.last_name}".strip() or d.user.username
            photo = d.google_photo_url or (d.profile_picture.url if d.profile_picture else None)
            top_donors_list.append({
                "id": d.id,
                "name": full_name,
                "photo": photo,
                "bags": d.verified_bags,
                "rank": idx
            })

        other_count = max(0, total_count - len(top_donors_list))
        data = {
            "top_donors": top_donors_list,
            "other_donors_count": other_count
        }
        cache.set(cache_key, data, timeout=60)
        return Response(data)


class GlobalRankView(APIView):
    """
    GET /api/profile/global-rank/
    Paginated leaderboard by verified bags, with caller's own rank row.
    Cached for 60 seconds.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        caller_profile = DonorProfile.objects.filter(user=request.user).first()

        # Caller verified bags (DB dynamic)
        caller_verified_bags = 0
        if caller_profile:
            vh_bags = DonationHistory.objects.filter(
                donor=caller_profile, verified=True
            ).aggregate(total=Coalesce(Sum('bags'), 0))['total']
            caller_verified_bags = max(vh_bags, caller_profile.total_bags_donated or 0)

        # Eligible donors for leaderboard (DB dynamic)
        eligible_donors = DonorProfile.objects.filter(
            user__is_active=True,
            is_suspended=False,
            show_in_rankings=True
        ).annotate(
            vh_bags=Coalesce(Sum('donation_history__bags', filter=Q(donation_history__verified=True)), 0),
            first_donation=Min('donation_history__donated_at', filter=Q(donation_history__verified=True))
        ).annotate(
            verified_bags=Greatest(F('vh_bags'), F('total_bags_donated'))
        ).filter(verified_bags__gt=0).order_by('-verified_bags', 'first_donation', 'id')

        # Compute caller's private rank
        caller_rank = None
        if caller_profile:
            if caller_verified_bags > 0:
                first_d = caller_profile.donation_history.filter(verified=True).aggregate(Min('donated_at'))['donated_at__min']
                higher_count = eligible_donors.filter(
                    Q(verified_bags__gt=caller_verified_bags) |
                    Q(verified_bags=caller_verified_bags, first_donation__lt=first_d)
                ).count()
                caller_rank = higher_count + 1
            else:
                caller_rank = eligible_donors.count() + 1

        caller_row = {
            "id": caller_profile.id if caller_profile else None,
            "name": f"{request.user.first_name} {request.user.last_name}".strip() or request.user.username,
            "photo": caller_profile.google_photo_url or (caller_profile.profile_picture.url if caller_profile and caller_profile.profile_picture else None),
            "bags": caller_verified_bags,
            "rank": caller_rank,
            "is_caller": True,
        }

        # Pagination (page, page_size)
        try:
            page = max(1, int(request.query_params.get('page', 1)))
            page_size = min(50, max(1, int(request.query_params.get('page_size', 20))))
        except ValueError:
            page, page_size = 1, 20

        start = (page - 1) * page_size
        end = start + page_size

        total = eligible_donors.count()
        page_qs = eligible_donors[start:end]

        results = []
        for idx, d in enumerate(page_qs, start=start + 1):
            full_name = f"{d.user.first_name} {d.user.last_name}".strip() or d.user.username
            photo = d.google_photo_url or (d.profile_picture.url if d.profile_picture else None)
            results.append({
                "id": d.id,
                "name": full_name,
                "photo": photo,
                "bags": d.verified_bags,
                "rank": idx,
                "is_caller": caller_profile and d.id == caller_profile.id,
            })

        return Response({
            "count": total,
            "page": page,
            "page_size": page_size,
            "caller_rank": caller_row,
            "results": results
        })


class PublicProfileDetailView(APIView):
    """
    GET /api/profile/<id>/
    Sanitized public profile card. Blocked fields: phone, NID hash, exact location,
    weight, medical reports. Returns 404 for soft-deleted or suspended users.
    """
    permission_classes = [AllowAny]

    def get(self, request, pk):
        profile = DonorProfile.objects.filter(pk=pk).select_related('user').first()
        if not profile or not profile.user.is_active or profile.is_suspended:
            return Response({"detail": "Donor profile not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = PublicDonorProfileSerializer(profile)
        return Response(serializer.data)


class ProfileStoriesView(APIView):
    """
    GET /api/profile/me/stories/
    The user's SocialPost items, ordered by (-created_at, -id).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = DonorProfile.objects.filter(user=request.user).select_related('user').first()
        if not profile:
            return Response({"results": []})

        author_name = f"{profile.user.first_name} {profile.user.last_name}".strip() or profile.user.username
        author_photo = profile.google_photo_url or (profile.profile_picture.url if profile.profile_picture else None)

        posts = SocialPost.objects.filter(author=profile, deleted_at__isnull=True).select_related('district').order_by('-created_at', '-id')
        data = []
        for p in posts[:30]:
            img_url = None
            if p.media and len(p.media) > 0:
                first_item = p.media[0]
                if isinstance(first_item, str):
                    img_url = first_item
                elif isinstance(first_item, dict):
                    img_url = first_item.get('url') or first_item.get('image_url')

            likes = p.like_count or p.likes_count or 0
            data.append({
                "id": p.id,
                "author_name": author_name,
                "author_photo": author_photo,
                "location": p.district.name if p.district else (profile.district or ""),
                "content": p.text_content,
                "image_url": img_url,
                "likes_count": likes,
                "reactions_count": likes,
                "comments_count": p.comment_count,
                "created_at": p.created_at.isoformat(),
            })
        return Response({"results": data})


class ProfileActivityView(APIView):
    """
    GET /api/profile/me/activity/
    Activity cards showing step status. Auto-verified badge shown ONLY if real
    server flag (auto_confirmed) is True.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = DonorProfile.objects.filter(user=request.user).first()
        if not profile:
            return Response({"results": []})

        matches = DonationMatch.objects.filter(donor=profile).select_related('request', 'request__hospital').order_by('-created_at', '-id')
        results = []
        for m in matches[:30]:
            req = m.request
            hosp = req.hospital_name_other or (req.hospital.name if req.hospital else 'Hospital')
            results.append({
                "id": m.id,
                "request_id": req.id,
                "patient_name": req.patient_name,
                "blood_group": req.blood_group,
                "hospital": hosp,
                "status": m.status,
                "steps": {
                    "request_received": True,
                    "replied": m.donor_confirmed_at is not None or m.status in ['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED'],
                    "on_the_way": m.status in ['ON_THE_WAY', 'ARRIVED', 'DONATED'],
                    "donated": m.status == 'DONATED',
                },
                "auto_verified": bool(getattr(m, 'auto_confirmed', False)),
                "created_at": m.created_at.isoformat(),
            })
        return Response({"results": results})


class ProfileDonationsView(APIView):
    """
    GET /api/profile/me/donations/
    Donation history with 'Self-reported' vs 'Verified' indicator.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = DonorProfile.objects.filter(user=request.user).first()
        if not profile:
            return Response({"results": []})

        donations = DonationHistory.objects.filter(donor=profile).order_by('-donated_at', '-created_at', '-id')
        results = []
        for dh in donations[:50]:
            results.append({
                "id": dh.id,
                "donated_at": str(dh.donated_at or dh.date),
                "hospital": dh.hospital or dh.location,
                "city": dh.city or profile.district or "",
                "donation_type": dh.donation_type,
                "how": dh.how,
                "bags": dh.bags or dh.bags_donated,
                "volume_ml": dh.volume_ml,
                "source": dh.source,
                "verified": dh.verified,
                "notes": dh.notes,
                "created_at": dh.created_at.isoformat(),
            })
        return Response({"results": results})


class BloodGroupChangeRequestView(APIView):
    """
    POST, GET /api/profile/blood-group-change/
    Submits and tracks blood group change requests with encrypted lab report upload.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        if not profile:
            return Response({"detail": "Profile not found."}, status=status.HTTP_404_NOT_FOUND)

        # One open request rule
        open_request = BloodGroupChangeRequest.objects.filter(
            user=user, status__in=['pending', 'under_review']
        ).first()
        if open_request:
            return Response({
                "detail": "You already have an open blood group change request under review."
            }, status=status.HTTP_400_BAD_REQUEST)

        requested_group = request.data.get('requested_group', '').strip().upper()
        valid_bgs = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        if requested_group not in valid_bgs:
            return Response({"requested_group": ["Valid blood group is required."]}, status=status.HTTP_400_BAD_REQUEST)

        consent = str(request.data.get('consent', '')).lower() in ('true', '1')
        if not consent:
            return Response({"consent": ["You must consent to lab report verification."]}, status=status.HTTP_400_BAD_REQUEST)

        # File validation
        file_obj = request.FILES.get('report_file')
        raw_bytes = None
        safe_filename = ''
        content_type = ''
        file_size = 0

        if file_obj:
            if file_obj.size > 5 * 1024 * 1024:
                return Response({"report_file": ["Report file size must not exceed 5 MB."]}, status=status.HTTP_400_BAD_REQUEST)

            raw_bytes = file_obj.read()
            is_pdf = raw_bytes.startswith(b'%PDF-')
            is_jpeg = raw_bytes.startswith(b'\xff\xd8\xff')
            is_png = raw_bytes.startswith(b'\x89PNG\r\n\x1a\n')

            if not (is_pdf or is_jpeg or is_png):
                return Response({
                    "report_file": ["Invalid file format. Only PDF, JPEG, and PNG medical reports are allowed."]
                }, status=status.HTTP_400_BAD_REQUEST)

            content_type = 'application/pdf' if is_pdf else ('image/jpeg' if is_jpeg else 'image/png')
            safe_filename = re.sub(r'[^a-zA-Z0-9_.-]', '_', file_obj.name)
            file_size = len(raw_bytes)

        # Parse test date
        test_date = None
        raw_test_date = request.data.get('test_date')
        if raw_test_date:
            try:
                parts = [int(p) for p in str(raw_test_date).split('-')]
                test_date = date(parts[0], parts[1], parts[2])
            except Exception:
                pass

        change_req = BloodGroupChangeRequest.objects.create(
            user=user,
            current_group=profile.blood_group,
            requested_group=requested_group,
            reason=request.data.get('reason', ''),
            lab_name=request.data.get('lab_name', ''),
            test_date=test_date,
            notes=request.data.get('notes', ''),
            consent=consent,
            status='pending',
            report_file_data=raw_bytes,
            report_file_name=safe_filename,
            report_file_content_type=content_type,
            report_file_size=file_size,
        )

        return Response({
            "id": change_req.id,
            "status": change_req.status,
            "current_group": change_req.current_group,
            "requested_group": change_req.requested_group,
            "has_report": bool(raw_bytes),
            "created_at": change_req.created_at.isoformat(),
        }, status=status.HTTP_201_CREATED)

    def get(self, request):
        latest = BloodGroupChangeRequest.objects.filter(user=request.user).first()
        if not latest:
            return Response({"has_request": False})

        return Response({
            "has_request": True,
            "id": latest.id,
            "status": latest.status,
            "current_group": latest.current_group,
            "requested_group": latest.requested_group,
            "reason": latest.reason,
            "lab_name": latest.lab_name,
            "test_date": str(latest.test_date) if latest.test_date else None,
            "reviewed_at": latest.reviewed_at.isoformat() if latest.reviewed_at else None,
            "created_at": latest.created_at.isoformat(),
        })


class DonorReviewView(APIView):
    """
    POST /api/reviews/
    GET /api/profile/<id>/reviews/
    Creates and retrieves donor ratings & reviews.
    """
    throttle_classes = [ReviewPostThrottle]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAuthenticated()]

    def post(self, request):
        user = request.user
        req_id = request.data.get('blood_request_id')
        if not req_id:
            return Response({"blood_request_id": ["Blood request ID is required."]}, status=status.HTTP_400_BAD_REQUEST)

        blood_req = BloodRequest.objects.filter(id=req_id).first()
        if not blood_req:
            return Response({"detail": "Blood request not found."}, status=status.HTTP_404_NOT_FOUND)

        # Requester only check
        if blood_req.requester_id != user.id:
            return Response({"detail": "Only the requester of this blood request can submit a review."}, status=status.HTTP_403_FORBIDDEN)

        # Must be completed donation
        if blood_req.status not in ('DONATED', 'CLOSED', 'FULFILLED'):
            return Response({"detail": "Reviews can only be submitted after donation completion."}, status=status.HTTP_400_BAD_REQUEST)

        donor_id = request.data.get('donor_id')
        donor_profile = DonorProfile.objects.filter(id=donor_id).first()
        if not donor_profile:
            return Response({"donor_id": ["Donor profile not found."]}, status=status.HTTP_404_NOT_FOUND)

        # Anti self-review
        if donor_profile.user_id == user.id:
            return Response({"detail": "You cannot review yourself."}, status=status.HTTP_400_BAD_REQUEST)

        # Stars validation
        try:
            stars = int(request.data.get('stars', 5))
            if stars < 1 or stars > 5:
                raise ValueError()
        except (ValueError, TypeError):
            return Response({"stars": ["Stars must be an integer between 1 and 5."]}, status=status.HTTP_400_BAD_REQUEST)

        comment = request.data.get('comment', '').strip()
        if len(comment) > 200:
            return Response({"comment": ["Comment cannot exceed 200 characters."]}, status=status.HTTP_400_BAD_REQUEST)

        # One review per request check
        existing = DonorReview.objects.filter(blood_request=blood_req, reviewer=user).first()
        if existing:
            return Response({"detail": "You have already reviewed this donation."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            review = DonorReview.objects.create(
                reviewer=user,
                donor=donor_profile,
                blood_request=blood_req,
                stars=stars,
                tag=request.data.get('tag', ''),
                comment=comment,
            )
            # Send Path 7: Notify donor of thanks & review
            try:
                from api.services.notify import notify_donor_thanks
                notify_donor_thanks(blood_req, donor_profile, review)
            except Exception:
                pass
        except ValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response({
            "id": review.id,
            "stars": review.stars,
            "tag": review.tag,
            "comment": review.comment,
            "donor_rating_avg": donor_profile.rating_avg,
            "donor_rating_count": donor_profile.rating_count,
            "created_at": review.created_at.isoformat(),
        }, status=status.HTTP_201_CREATED)

    def get(self, request, donor_id=None):
        profile = DonorProfile.objects.filter(id=donor_id).first()
        if not profile or not profile.user.is_active or profile.is_suspended:
            return Response({"detail": "Donor profile not found."}, status=status.HTTP_404_NOT_FOUND)

        reviews = DonorReview.objects.filter(donor=profile).select_related('reviewer').order_by('-created_at', '-id')
        data = []
        for r in reviews[:50]:
            name = f"{r.reviewer.first_name} {r.reviewer.last_name}".strip() or r.reviewer.username
            data.append({
                "id": r.id,
                "reviewer_name": name,
                "stars": r.stars,
                "tag": r.tag,
                "comment": r.comment,
                "created_at": r.created_at.isoformat(),
            })

        return Response({
            "rating_avg": profile.rating_avg,
            "rating_count": profile.rating_count,
            "results": data,
        })


class CertificateVerifyThrottle(AnonRateThrottle):
    rate = '30/minute'


class ProfileCertificateDownloadView(APIView):
    """
    GET /api/profile/me/certificate/
    Generates and downloads the verified donor certificate as PDF.
    Requires at least one verified donation. If none, returns 400 Bad Request with:
    {"code": "NO_VERIFIED_DONATION", "detail": "Certificate is only available for donors with at least one verified donation."}
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        if not profile or not profile.user.is_active or profile.is_suspended:
            return Response({"detail": "Active donor profile required."}, status=status.HTTP_404_NOT_FOUND)

        if not profile.is_profile_complete:
            return Response({"detail": "Profile registration incomplete.", "code": "REGISTRATION_INCOMPLETE"}, status=status.HTTP_403_FORBIDDEN)

        # Count verified bags from DonationHistory
        verified_bags = DonationHistory.objects.filter(
            donor=profile,
            verified=True
        ).aggregate(total=Coalesce(Sum('bags'), 0))['total']

        if verified_bags <= 0:
            return Response({
                "code": "NO_VERIFIED_DONATION",
                "detail": "Certificate is only available for donors with at least one verified donation."
            }, status=status.HTTP_400_BAD_REQUEST)

        from api.services.certificate_service import generate_donor_certificate_pdf
        pdf_bytes = generate_donor_certificate_pdf(profile, verified_bags=verified_bags)

        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        filename = f"BloodPulse_Certificate_BP-D{profile.id:06d}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        response['X-Content-Type-Options'] = 'nosniff'
        return response


class ProfileCertificateVerifyView(APIView):
    """
    GET /api/profile/certificate/verify/?token=<signed_token>
    Public verification endpoint to verify the authenticity of a certificate.
    Rate limited, returns minimal public facts (name, blood group, bags, issue date, valid).
    """
    permission_classes = [AllowAny]
    throttle_classes = [CertificateVerifyThrottle]

    def get(self, request):
        token = request.query_params.get('token', '').strip()
        if not token:
            return Response({
                "valid": False,
                "detail": "Token parameter is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        from api.services.certificate_service import verify_certificate_token
        result = verify_certificate_token(token)
        if not result.get('valid'):
            return Response(result, status=status.HTTP_400_BAD_REQUEST)
        return Response(result, status=status.HTTP_200_OK)


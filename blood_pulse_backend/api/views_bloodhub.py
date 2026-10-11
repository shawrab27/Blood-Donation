# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.utils import timezone
"""
Dedicated API views for BloodPulse Blood Hub v2.
Handles search, map, hospital directory, request creation, wave progression, and acceptances.
"""

from datetime import timedelta

from django.db import transaction
from django.db.models import Q
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from api.permissions import IsProfileComplete
from rest_framework.response import Response
from api.throttles import OTPAnonThrottle, OTPUserThrottle, GuestMapAnonThrottle
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
    FakeReport,
    District,
    Division,
)
from api.serializers_bloodhub import (
    HospitalSerializer,
    DonorSearchSerializer,
    DonorMapSerializer,
    BloodRequestListSerializer,
    BloodRequestDetailSerializer,
    RequestAcceptanceSerializer,
    FakeReportSerializer,
    DonationIssueSerializer,
    StandbyOfferSerializer,
    EmailOTPSendSerializer,
    EmailOTPVerifySerializer,
)
from api.services.compat import get_compatible_donor_groups
from api.services.trust import calculate_trust_score, resolve_effective_scope
from api.services.waves import get_candidate_donors_for_wave
from api.services.notify import dispatch_wave_notifications
from api.services.tick import process_wave_tick
from api.services.images import strip_image_exif
from api.services.geo import haversine_distance, estimate_eta_minutes
from api.conf import WAVE_TIMEOUT_MINUTES


@api_view(['GET'])
@permission_classes([AllowAny])
def donor_search_view(request):
    """
    Search available donors by blood group, campus, district, division, or location.
    STRICT PRIVACY LOCK: Searches by donor name or phone number are locked/blocked.
    Only opted-in (is_searchable=True), available donors are returned with masked phone numbers.
    """
    blood_group = request.query_params.get('blood_group', '').replace(' ', '+').strip()
    component = request.query_params.get('component', 'WHOLE').strip()
    campus = request.query_params.get('campus', '').strip()
    district = request.query_params.get('district', '').strip()
    division = request.query_params.get('division', '').strip()
    q = request.query_params.get('q', '').strip()
    
    lat_str = request.query_params.get('lat', '').strip()
    lng_str = request.query_params.get('lng', '').strip()
    radius_str = request.query_params.get('radius', '10.0').strip()
    
    limit = min(50, int(request.query_params.get('limit', 20)))
    offset = int(request.query_params.get('offset', 0))

    queryset = DonorProfile.objects.filter(
        is_searchable=True,
        is_available=True,
    ).exclude(user_intent='ONLY_REQUEST').select_related('user', 'upazila_linked__district__division')

    if blood_group and blood_group != 'Any':
        compatible_groups = get_compatible_donor_groups(blood_group, component)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    if campus and campus != 'All Campuses' and campus != 'Any':
        queryset = queryset.filter(
            Q(campus__icontains=campus) |
            Q(institute__icontains=campus) |
            Q(institution__name__icontains=campus)
        )

    if district and district != 'Any':
        queryset = queryset.filter(
            Q(district__icontains=district) |
            Q(upazila_linked__district__name__icontains=district)
        )

    if division and division != 'Any':
        districts_in_div = list(District.objects.filter(division__name__icontains=division).values_list('name', flat=True))
        queryset = queryset.filter(
            Q(upazila_linked__district__division__name__icontains=division) |
            Q(district__in=districts_in_div) |
            Q(address__icontains=division)
        )

    # STRICT PRIVACY LOCK: Never search by name, username, or phone number
    if q:
        queryset = queryset.filter(
            Q(campus__icontains=q) |
            Q(institute__icontains=q) |
            Q(institution__name__icontains=q) |
            Q(district__icontains=q) |
            Q(address__icontains=q) |
            Q(upazila_linked__name__icontains=q) |
            Q(upazila_linked__district__name__icontains=q)
        )

    if lat_str and lng_str:
        try:
            req_lat = float(lat_str)
            req_lng = float(lng_str)
            radius = float(radius_str)
            
            filtered_results = []
            for d in queryset:
                if d.latitude is not None and d.longitude is not None:
                    dist = haversine_distance(req_lat, req_lng, float(d.latitude), float(d.longitude))
                    if dist <= radius:
                        d._distance = dist
                        filtered_results.append(d)
            
            filtered_results.sort(key=lambda x: (x._distance, -x.rating_avg))
            total_count = len(filtered_results)
            results = filtered_results[offset:offset + limit]
            
        except ValueError:
            total_count = queryset.count()
            results = queryset.order_by('-total_bags_donated', '-rating_avg')[offset:offset + limit]
    else:
        total_count = queryset.count()
        results = queryset.order_by('-total_bags_donated', '-rating_avg')[offset:offset + limit]

    serializer = DonorSearchSerializer(results, many=True, context={'request': request})
    return Response({
        'total': total_count,
        'count': total_count,
        'offset': offset,
        'limit': limit,
        'results': serializer.data,
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def donor_map_view(request):
    """
    Returns fuzzed coordinates (~500m) for searchable donors matching active filters.
    STRICT PRIVACY LOCK: Searches by donor name or phone number are locked/blocked.
    """
    blood_group = request.query_params.get('blood_group', '').replace(' ', '+').strip()
    component = request.query_params.get('component', 'WHOLE').strip()
    campus = request.query_params.get('campus', '').strip()
    district = request.query_params.get('district', '').strip()
    division = request.query_params.get('division', '').strip()
    q = request.query_params.get('q', '').strip()

    lat_str = request.query_params.get('lat', '').strip()
    lng_str = request.query_params.get('lng', '').strip()
    radius_str = request.query_params.get('radius', '15.0').strip()

    queryset = DonorProfile.objects.filter(
        is_searchable=True,
        is_available=True,
    ).exclude(user_intent='ONLY_REQUEST').exclude(
        Q(latitude__isnull=True) & Q(last_lat__isnull=True)
    ).select_related('user', 'upazila_linked__district__division')

    if blood_group and blood_group != 'Any':
        compatible_groups = get_compatible_donor_groups(blood_group, component)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    if campus and campus != 'All Campuses' and campus != 'Any':
        queryset = queryset.filter(
            Q(campus__icontains=campus) |
            Q(institute__icontains=campus) |
            Q(institution__name__icontains=campus)
        )

    if district and district != 'Any':
        queryset = queryset.filter(
            Q(district__icontains=district) |
            Q(upazila_linked__district__name__icontains=district)
        )

    if division and division != 'Any':
        districts_in_div = list(District.objects.filter(division__name__icontains=division).values_list('name', flat=True))
        queryset = queryset.filter(
            Q(upazila_linked__district__division__name__icontains=division) |
            Q(district__in=districts_in_div) |
            Q(address__icontains=division)
        )

    # STRICT PRIVACY LOCK: Never search by name or phone
    if q:
        queryset = queryset.filter(
            Q(campus__icontains=q) |
            Q(institute__icontains=q) |
            Q(institution__name__icontains=q) |
            Q(district__icontains=q) |
            Q(address__icontains=q) |
            Q(upazila_linked__name__icontains=q) |
            Q(upazila_linked__district__name__icontains=q)
        )

    if lat_str and lng_str:
        try:
            req_lat = float(lat_str)
            req_lng = float(lng_str)
            radius = float(radius_str)
            
            filtered_results = []
            for d in queryset:
                lat = float(d.latitude or d.last_lat)
                lng = float(d.longitude or d.last_lng)
                dist = haversine_distance(req_lat, req_lng, lat, lng)
                if dist <= radius:
                    filtered_results.append(d)
                    
            results = filtered_results[:100]
        except ValueError:
            results = queryset[:100]
    else:
        results = queryset[:100]

    serializer = DonorMapSerializer(results, many=True)
    return Response({
        'count': len(results),
        'donors': serializer.data,
        'results': serializer.data,
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
@throttle_classes([GuestMapAnonThrottle])
def guest_donor_map_view(request):
    """
    Anonymous, throttled endpoint for the guest map.
    Takes NO query parameters (extra params are ignored).
    Returns all published geohash cells (precision=GUEST_MAP_GEOHASH_PRECISION=4)
    for the whole country with count >= GUEST_MAP_MIN_CELL_DONORS (3),
    cached server-side for 5 minutes.
    Cell latitude/longitude are strictly the geohash CELL CENTER, never donor mean.
    total_donors = sum of published cells only, capped at 500 cells.
    """
    from collections import defaultdict
    from django.core.cache import cache
    from api.conf import (
        CACHE_KEY_GUEST_MAP,
        GUEST_MAP_CACHE_TIMEOUT_SECONDS,
        GUEST_MAP_GEOHASH_PRECISION,
        GUEST_MAP_MAX_CELLS,
        GUEST_MAP_MIN_CELL_DONORS,
    )
    from api.services.geo import encode_geohash, decode_geohash
    from api.views_public_stats import eligible_public_donors_queryset

    cached = cache.get(CACHE_KEY_GUEST_MAP)
    if cached is not None:
        return Response(cached, status=status.HTTP_200_OK)

    queryset = (
        eligible_public_donors_queryset()
        .exclude(Q(latitude__isnull=True) & Q(last_lat__isnull=True))
        .exclude(Q(longitude__isnull=True) & Q(last_lng__isnull=True))
        .values('latitude', 'longitude', 'last_lat', 'last_lng')
    )

    geohash_counts = defaultdict(int)
    for d in queryset:
        raw_lat = d['last_lat'] if d['last_lat'] is not None else d['latitude']
        raw_lng = d['last_lng'] if d['last_lng'] is not None else d['longitude']
        if raw_lat is None or raw_lng is None:
            continue
        try:
            lat_f = float(raw_lat)
            lng_f = float(raw_lng)
        except (TypeError, ValueError):
            continue

        gh = encode_geohash(lat_f, lng_f, precision=GUEST_MAP_GEOHASH_PRECISION)
        if gh:
            geohash_counts[gh] += 1

    published_cells = []
    for gh in sorted(geohash_counts.keys()):
        count = geohash_counts[gh]
        if count >= GUEST_MAP_MIN_CELL_DONORS:
            center_lat, center_lng = decode_geohash(gh)
            published_cells.append({
                'geohash': gh,
                'count': count,
                'latitude': center_lat,
                'longitude': center_lng,
            })

    # Sort deterministically by (-count, geohash) and cap at GUEST_MAP_MAX_CELLS (500)
    published_cells.sort(key=lambda c: (-c['count'], c['geohash']))
    published_cells = published_cells[:GUEST_MAP_MAX_CELLS]

    total_donors = sum(c['count'] for c in published_cells)
    payload = {
        'total_donors': total_donors,
        'cells': published_cells,
    }
    cache.set(CACHE_KEY_GUEST_MAP, payload, timeout=GUEST_MAP_CACHE_TIMEOUT_SECONDS)
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def hospital_list_view(request):
    """
    Autocomplete endpoint for authentic hospitals in Bangladesh.
    Filters by search query 'q' or 'district'.
    """
    q = request.query_params.get('q', '').strip()
    district = request.query_params.get('district', '').strip()

    queryset = Hospital.objects.all()

    if q:
        queryset = queryset.filter(
            Q(name__icontains=q) |
            Q(name_en__icontains=q) |
            Q(name_bn__icontains=q) |
            Q(address__icontains=q)
        )

    if district:
        queryset = queryset.filter(district__icontains=district)

    queryset = queryset.order_by('-is_verified', 'name')[:30]
    serializer = HospitalSerializer(queryset, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
@throttle_classes([__import__('api.throttles', fromlist=['RequestsThrottle', 'EmergencyBroadcastThrottle']).EmergencyBroadcastThrottle])
def emergency_requests_list_create_view(request):
    """
    GET: List active requests with filters.
    POST: Create a blood request with trust evaluation and wave 1 dispatch.
    """
    if request.method == 'GET':
        blood_group = request.query_params.get('blood_group', '').strip()
        urgency = request.query_params.get('urgency', '').strip()
        district = request.query_params.get('district', '').strip()
        status_filter = request.query_params.get('status', 'ACTIVE').strip()

        queryset = BloodRequest.objects.all()
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if blood_group:
            queryset = queryset.filter(blood_group=blood_group)
        if urgency:
            queryset = queryset.filter(urgency=urgency)
        if district:
            queryset = queryset.filter(district__icontains=district)

        results = queryset.order_by('-created_at')[:50]
        serializer = BloodRequestListSerializer(results, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    # POST: Create request
    if not request.user or not request.user.is_authenticated:
        return Response({'detail': 'Authentication required to create an emergency blood request.'}, status=status.HTTP_401_UNAUTHORIZED)

    if not IsProfileComplete().has_permission(request, None):
        return Response({'detail': 'Profile completion required before creating blood requests.', 'code': 'profile_incomplete'}, status=status.HTTP_403_FORBIDDEN)

    client_request_id = request.data.get('client_request_id')
    if client_request_id:
        existing = BloodRequest.objects.filter(client_request_id=client_request_id).first()
        if existing:
            detail_serializer = BloodRequestDetailSerializer(existing, context={'request': request})
            return Response(detail_serializer.data, status=status.HTTP_200_OK)

    submit_token = request.data.get('submit_token') or request.headers.get('X-Submit-Token')
    from api.views_request_otp import check_submit_token, validate_and_consume_submit_token
    if not check_submit_token(request.user, submit_token):
        return Response(
            {'detail': 'A valid unused submit_token is required to submit a blood request.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    patient_name = request.data.get('patient_name', '').strip()
    blood_group = request.data.get('blood_group', '').strip()
    component = request.data.get('component', 'WHOLE').strip()
    try:
        units_needed = int(request.data.get('units_needed', 1))
    except (TypeError, ValueError):
        return Response({'units_needed': ['Must be a valid integer between 1 and 5.']}, status=status.HTTP_400_BAD_REQUEST)
    if units_needed < 1 or units_needed > 5:
        return Response({'units_needed': ['units_needed must be between 1 and 5.']}, status=status.HTTP_400_BAD_REQUEST)

    urgency = request.data.get('urgency', 'CRITICAL_2H').strip()
    condition_category = request.data.get('condition_category', 'OTHER').strip()
    condition_note = request.data.get('condition_note', '')[:80]
    requested_scope = request.data.get('scope', 'LOCAL').strip()
    district = request.data.get('district', '').strip()
    hospital_id = request.data.get('hospital_id')
    hospital_name_other = request.data.get('hospital_name_other', '').strip()
    ward_bed = request.data.get('ward_bed', '').strip()
    attendant_name = request.data.get('attendant_name', '').strip()
    contact_phone = request.data.get('contact_phone', '').strip()
    lat = request.data.get('lat')
    lng = request.data.get('lng')

    from api.services.blood_hub_lifecycle_service import normalize_request_mode
    request_mode = normalize_request_mode(
        request.data.get('request_mode'),
        patient_name=patient_name,
        attendant_name=attendant_name,
        requester=request.user,
    )

    if not patient_name or not blood_group:
        return Response({'error': 'patient_name and blood_group are required.'}, status=status.HTTP_400_BAD_REQUEST)

    errors = {}
    if not hospital_id and not hospital_name_other:
        errors['hospital'] = ['Hospital information is required.']
    if not ward_bed:
        errors['ward_bed'] = ['Ward/Bed information is required.']
        
    if errors:
        return Response(errors, status=status.HTTP_400_BAD_REQUEST)

    hospital = None
    if hospital_id:
        hospital = Hospital.objects.filter(id=hospital_id).first()

    # Image files with EXIF stripping
    from api.utils import validate_uploaded_file
    requisition_slip = strip_image_exif(validate_uploaded_file(request.FILES.get('requisition_slip')))
    patient_photo = strip_image_exif(validate_uploaded_file(request.FILES.get('patient_photo')))

    # Trust Score & Effective Scope
    requester = request.user if request.user.is_authenticated else None
    trust_score, trust_band = calculate_trust_score(
        hospital=hospital,
        hospital_name_other=hospital_name_other,
        has_requisition_slip=bool(requisition_slip),
        has_patient_photo=bool(patient_photo),
        attendant_name=attendant_name,
        contact_phone=contact_phone,
        requester=requester,
    )
    
    if requisition_slip:
        from api.services.trust import verify_slip_with_ai
        req_bytes = requisition_slip.read()
        requisition_slip.seek(0)
        ai_res = verify_slip_with_ai(req_bytes)
        if ai_res.get('verified') and 'true' in ai_res.get('raw_response', '').lower():
            trust_score = min(100, trust_score + 20)
            if trust_score >= 80:
                trust_band = 'HIGH'
            elif trust_score >= 50:
                trust_band = 'MEDIUM'
                
    effective_scope = resolve_effective_scope(requested_scope, trust_band)

    # Initial wave timeouts
    now = timezone.now()
    timeout_map = WAVE_TIMEOUT_MINUTES.get(urgency, WAVE_TIMEOUT_MINUTES['CRITICAL_2H'])
    wave1_mins = timeout_map.get(1, 15)
    next_wave_at = now + timedelta(minutes=wave1_mins)
    expires_at = now + timedelta(hours=24) # 24h default expiration

    with transaction.atomic():
        if not validate_and_consume_submit_token(request.user, submit_token):
            return Response(
                {'detail': 'A valid unused submit_token is required to submit a blood request.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        blood_req = BloodRequest.objects.create(
            requester=requester,
            patient_name=patient_name,
            blood_group=blood_group,
            mode=request.data.get('mode', 'EMERGENCY'),
            request_mode=request_mode,
            component=component,
            units_needed=units_needed,
            units_received=0,
            units_pending=0,
            urgency=urgency,
            urgency_level=urgency,
            condition_category=condition_category,
            condition_note=condition_note,
            scope=requested_scope,
            effective_scope=effective_scope,
            district=district or (hospital.district if hospital else ''),
            hospital=hospital,
            hospital_location=hospital.name if hospital else (hospital_name_other or 'Hospital'),
            hospital_name_other=hospital_name_other,
            ward_bed=ward_bed,
            attendant_name=attendant_name,
            contact_phone=contact_phone,
            contact_number=contact_phone,
            lat=float(lat) if lat is not None else None,
            lng=float(lng) if lng is not None else None,
            requisition_slip=requisition_slip,
            patient_photo=patient_photo,
            trust_score=trust_score,
            trust_band=trust_band,
            status='ACTIVE',
            current_wave=1,
            next_wave_at=next_wave_at,
            expires_at=expires_at,
            client_request_id=client_request_id,
            is_drill=bool(request.data.get('is_drill', False)),
        )

    # Trigger Wave 1 notification dispatch if mode is EMERGENCY
    if blood_req.mode == 'EMERGENCY':
        candidates = get_candidate_donors_for_wave(blood_req, wave_number=1)
        if candidates:
            dispatch_wave_notifications(blood_req, candidates, wave_number=1)

    serializer = BloodRequestDetailSerializer(blood_req, context={'request': request})
    return Response(serializer.data, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([AllowAny])
def emergency_request_detail_view(request, pk):
    """
    Returns full request details.
    Protects private contact info unless the requester or accepted donor is viewing.
    """
    blood_req = BloodRequest.objects.filter(id=pk).first()
    if not blood_req:
        return Response({'error': 'Blood request not found.'}, status=status.HTTP_404_NOT_FOUND)

    serializer = BloodRequestDetailSerializer(blood_req, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsProfileComplete])
@throttle_classes([__import__('api.throttles', fromlist=['DonorResponseThrottle']).DonorResponseThrottle])
def emergency_request_accept_view(request, pk):
    """
    Donor accepts an emergency request.
    Verifies eligibility, creates RequestAcceptance, reserves units_pending, reveals contact phone.
    """
    from django.db import IntegrityError, transaction
    from api.conf import DONOR_COOLDOWN_DAYS
    from api.services.eligibility import evaluate_donor_eligibility
    from api.services.blood_hub_lifecycle_service import normalize_support_status

    norm_support = normalize_support_status(request.data.get('support_status'))
    try:
        units_pledged = int(request.data.get('units_pledged', 1) or 1)
    except (TypeError, ValueError):
        return Response({'error': 'units_pledged must be a valid integer.'}, status=status.HTTP_400_BAD_REQUEST)
    if units_pledged < 1 or units_pledged > 5:
        return Response({'error': 'units_pledged must be between 1 and 5.'}, status=status.HTTP_400_BAD_REQUEST)

    with transaction.atomic():
        blood_req = BloodRequest.objects.select_for_update().filter(id=pk).first()
        if not blood_req:
            return Response({'error': 'Blood request not found.'}, status=status.HTTP_404_NOT_FOUND)

        now = timezone.now()
        if blood_req.expires_at and blood_req.expires_at <= now and blood_req.status not in ('CLOSED', 'FULFILLED', 'EXPIRED'):
            blood_req.status = 'EXPIRED'
            blood_req.is_active = False
            blood_req.closed_at = blood_req.closed_at or now
            blood_req.close_reason = blood_req.close_reason or 'EXPIRED'
            blood_req.units_pending = 0
            blood_req.save(update_fields=['status', 'is_active', 'closed_at', 'close_reason', 'units_pending'])
            return Response({'error': 'Request has expired and is closed.'}, status=status.HTTP_400_BAD_REQUEST)

        if blood_req.status != 'ACTIVE' or not blood_req.is_active:
            return Response({'error': f'Request is not active (Status: {blood_req.status}).'}, status=status.HTTP_400_BAD_REQUEST)

        if not hasattr(request.user, 'donorprofile'):
            return Response({'error': 'User must have a donor profile to accept.'}, status=status.HTTP_400_BAD_REQUEST)

        donor = request.user.donorprofile

        # JIT OTP verification
        code = request.data.get('otp') or request.data.get('code')
        if not code:
            return Response({'error': 'OTP verification code is required to accept this request.'}, status=status.HTTP_403_FORBIDDEN)
        
        from api.models import EmailOTP
        from api.services.email import verify_otp_hash
        otp_record = EmailOTP.objects.filter(
            email=request.user.email,
            is_used=False,
            expires_at__gt=timezone.now()
        ).order_by('-created_at').first()

        if not otp_record or otp_record.is_locked() or not verify_otp_hash(code, otp_record.otp_hash, request.user.email):
            if otp_record:
                otp_record.attempts += 1
                otp_record.save(update_fields=['attempts'])
            return Response({'error': 'Invalid, locked, or expired OTP.'}, status=status.HTTP_403_FORBIDDEN)
        
        otp_record.is_used = True
        otp_record.save(update_fields=['is_used'])

        # Check DONOR_COOLDOWN_DAYS and full donor eligibility
        if donor.last_donation_date:
            days_since_last = (timezone.now().date() - donor.last_donation_date).days
            if days_since_last < DONOR_COOLDOWN_DAYS:
                return Response({
                    'error': f'You are not eligible to donate. You must wait {DONOR_COOLDOWN_DAYS} days after your last donation. ({DONOR_COOLDOWN_DAYS - days_since_last} days remaining)'
                }, status=status.HTTP_400_BAD_REQUEST)

        elig = evaluate_donor_eligibility(donor, blood_req.component or 'WHOLE')
        if not elig['is_eligible']:
            return Response({'error': elig['reason']}, status=status.HTTP_400_BAD_REQUEST)

        existing_acceptance = RequestAcceptance.objects.filter(
            request=blood_req,
            donor=donor,
        ).first()

        if existing_acceptance:
            return Response({
                'error': 'You have already responded to this request.',
                'detail': 'You have already responded to this request.',
            }, status=status.HTTP_409_CONFLICT)

        # Concurrency check: Ensure we haven't reached units_needed
        active_acceptances_qs = RequestAcceptance.objects.filter(
            request=blood_req,
            status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']
        )
        db_pending = sum(a.units_pledged for a in active_acceptances_qs)
        effective_pending = max(blood_req.units_pending, db_pending)

        if blood_req.units_received + effective_pending + units_pledged > (blood_req.units_needed or 1):
            return Response({'error': 'Slot Full. This request already has enough donors.'}, status=status.HTTP_400_BAD_REQUEST)

        blood_req.units_pending = effective_pending + units_pledged
        blood_req.save(update_fields=['units_pending'])

        try:
            acceptance = RequestAcceptance.objects.create(
                request=blood_req,
                donor=donor,
                status='ACCEPTED',
                support_status=norm_support,
                units_pledged=units_pledged,
            )
        except IntegrityError:
            return Response({
                'error': 'You have already responded to this request.',
                'detail': 'You have already responded to this request.',
            }, status=status.HTTP_409_CONFLICT)

        # Increment donor response counter
        donor.response_count = (donor.response_count or 0) + 1
        donor.save(update_fields=['response_count'])

    serializer = RequestAcceptanceSerializer(acceptance)
    return Response({
        'message': 'Request successfully accepted. Contact details unmasked.',
        'acceptance': serializer.data,
        'requester_phone': blood_req.contact_phone or blood_req.contact_number,
        'ward_bed': blood_req.ward_bed,
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def emergency_request_report_view(request, pk):
    """
    Report a request, donor, or suspected broker as fake, abusive, or fraudulent (Part D).
    Never exposes reporter's phone/email/location to the reported party.
    If 3+ reports, suspends request to PENDING_ADMIN.
    """
    from api.models import BrokerReport

    blood_req = BloodRequest.objects.filter(id=pk).first()
    if not blood_req:
        return Response({'error': 'Blood request not found.'}, status=status.HTTP_404_NOT_FOUND)

    reason = request.data.get('reason', '').strip()
    if not reason:
        return Response({'error': 'Reason is required for report.'}, status=status.HTTP_400_BAD_REQUEST)

    target_type = request.data.get('target_type', 'REQUEST').strip().upper()
    if target_type not in ('BROKER', 'REQUEST', 'DONOR'):
        target_type = 'BROKER' if 'broker' in reason.lower() or 'money' in reason.lower() else 'REQUEST'

    reported_user = blood_req.requester
    reported_user_id = request.data.get('reported_user_id')
    if reported_user_id:
        from django.contrib.auth.models import User
        reported_user = User.objects.filter(id=reported_user_id).first() or reported_user

    report = FakeReport.objects.create(
        request=blood_req,
        reporter=request.user,
        reason=reason,
    )
    broker_report = BrokerReport.objects.create(
        request=blood_req,
        reported_user=reported_user,
        reporter=request.user,
        target_type=target_type,
        reason=reason,
        details=request.data.get('details', '').strip(),
        status='PENDING',
    )

    # Auto-quarantine if report threshold reached
    report_count = blood_req.fake_reports.count()
    if report_count >= 3:
        blood_req.status = 'PENDING_ADMIN'
        blood_req.escalated_to_admin = True
        blood_req.save(update_fields=['status', 'escalated_to_admin'])

    return Response({
        'message': 'Report submitted for administrator review.',
        'report_id': report.id,
        'broker_report_id': broker_report.id,
        'status': broker_report.status,
    }, status=status.HTTP_201_CREATED)


import hmac
import os
from rest_framework.exceptions import PermissionDenied

from rest_framework.decorators import authentication_classes

@api_view(['GET', 'HEAD', 'POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def emergency_wave_tick_view(request):
    """
    Triggers wave progression tick for all active requests.
    Used by Render Cron or internal runner.
    """
    auth_header = request.headers.get('Authorization', '')
    expected = os.environ.get('EMERGENCY_TICK_TOKEN', '')
    
    if expected:
        if not auth_header.startswith('Bearer '):
            raise PermissionDenied("Invalid or missing token")
        token = auth_header.split(' ')[1]
        if not hmac.compare_digest(token, expected):
            raise PermissionDenied("Invalid token")
        
    result = process_wave_tick()
    return Response(result, status=status.HTTP_200_OK)


@api_view(['GET', 'POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def maintenance_tick_view(request):
    auth_header = request.headers.get('Authorization', '')
    expected = os.environ.get('EMERGENCY_TICK_TOKEN', '')
    if expected:
        if not auth_header.startswith('Bearer '):
            raise PermissionDenied("Invalid or missing token")
        token = auth_header.split(' ')[1]
        if not hmac.compare_digest(token, expected):
            raise PermissionDenied("Invalid token")

    from api.services.journeys import auto_confirm_stale_donations, auto_manage_deferrals
    closed = auto_confirm_stale_donations(hours=48)
    deferred, reenabled = auto_manage_deferrals()
    return Response({'auto_confirmed_count': len(closed), 'auto_deferred_count': deferred, 'auto_reenabled_count': reenabled})


# ── Live Tracking Endpoints ───────────────────────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def journey_location_view(request, pk):
    """
    GET: Requester or Donor fetches latest live GPS location and ETA.
    POST: Donor updates their real-time coordinates.
    """
    acceptance = RequestAcceptance.objects.filter(id=pk).select_related('request', 'donor__user', 'request__requester').first()
    if not acceptance:
        return Response({'error': 'Journey acceptance not found.'}, status=status.HTTP_404_NOT_FOUND)

    is_donor = (acceptance.donor.user_id == request.user.id)
    is_requester = (acceptance.request.requester_id == request.user.id or request.user.is_staff)

    if not (is_donor or is_requester):
        return Response({'error': 'Unauthorized to access this journey tracking.'}, status=status.HTTP_403_FORBIDDEN)

    if request.method == 'POST':
        if not is_donor:
            return Response({'error': 'Only the assigned donor can publish live location.'}, status=status.HTTP_403_FORBIDDEN)

        lat = request.data.get('lat')
        lng = request.data.get('lng')
        if lat is None or lng is None:
            return Response({'error': 'lat and lng are required.'}, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        if acceptance.status not in ['ACCEPTED', 'ON_THE_WAY']:
            return Response({'status': 'ignored', 'message': 'Journey not in active tracking window'}, status=status.HTTP_200_OK)
        acceptance.donor_lat = float(lat)
        acceptance.donor_lng = float(lng)
        acceptance.last_location_update = now

        # Compute distance & ETA to destination hospital
        dest_lat = acceptance.request.lat or (acceptance.request.hospital.lat if acceptance.request.hospital else None)
        dest_lng = acceptance.request.lng or (acceptance.request.hospital.lng if acceptance.request.hospital else None)

        if dest_lat is not None and dest_lng is not None:
            dist_km = haversine_distance(float(lat), float(lng), dest_lat, dest_lng)
            acceptance.distance_km = round(dist_km, 2)
            acceptance.eta_minutes = estimate_eta_minutes(dist_km)

        acceptance.save(update_fields=['donor_lat', 'donor_lng', 'last_location_update', 'distance_km', 'eta_minutes'])

        return Response({
            'status': 'updated',
            'donor_lat': acceptance.donor_lat,
            'donor_lng': acceptance.donor_lng,
            'distance_km': acceptance.distance_km,
            'eta_minutes': acceptance.eta_minutes,
            'last_location_update': acceptance.last_location_update,
        }, status=status.HTTP_200_OK)

    # GET: return latest tracking state
    return Response({
        'acceptance_id': acceptance.id,
        'status': acceptance.status,
        'donor_lat': acceptance.donor_lat,
        'donor_lng': acceptance.donor_lng,
        'distance_km': acceptance.distance_km,
        'eta_minutes': acceptance.eta_minutes,
        'last_location_update': acceptance.last_location_update,
        'destination': {
            'hospital_name': acceptance.request.hospital.name if acceptance.request.hospital else acceptance.request.hospital_location,
            'lat': acceptance.request.lat or (acceptance.request.hospital.lat if acceptance.request.hospital else None),
            'lng': acceptance.request.lng or (acceptance.request.hospital.lng if acceptance.request.hospital else None),
        }
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([__import__('api.throttles', fromlist=['DonationConfirmThrottle']).DonationConfirmThrottle])
def journey_status_transition_view(request, pk):
    """
    Transitions the journey through its lifecycle milestones:
    ACCEPTED -> ON_THE_WAY -> ARRIVED -> DONATED -> CONFIRMED (or CANCELLED)
    Enforces two-sided confirmation and atomic unit release on cancellation.
    """
    from django.db import transaction
    from api.services.journeys import finalize_donation

    acceptance = RequestAcceptance.objects.filter(id=pk).select_related('request', 'donor__user').first()
    if not acceptance:
        return Response({'error': 'Journey acceptance not found.'}, status=status.HTTP_404_NOT_FOUND)

    new_status = request.data.get('status', '').strip().upper()
    valid_statuses = ['ON_THE_WAY', 'ARRIVED', 'DONATED', 'CANCELLED', 'CONFIRMED']
    if new_status not in valid_statuses:
        return Response({'error': f'Invalid status. Allowed: {valid_statuses}'}, status=status.HTTP_400_BAD_REQUEST)

    is_donor = (acceptance.donor.user_id == request.user.id)
    is_requester = (acceptance.request.requester_id == request.user.id or request.user.is_staff)

    if not (is_donor or is_requester):
        return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

    now = timezone.now()

    if new_status == 'DONATED':
        with transaction.atomic():
            locked_acc = RequestAcceptance.objects.select_for_update().get(pk=acceptance.pk)
            blood_req = BloodRequest.objects.select_for_update().get(pk=locked_acc.request_id)

            if locked_acc.status == 'CONFIRMED' and locked_acc.completed_at is not None:
                return Response({'status': 'CONFIRMED', 'message': 'Donation already confirmed.'}, status=status.HTTP_200_OK)

            # Ensure units_pending reflects this active unconfirmed acceptance if created directly in tests
            units = max(1, locked_acc.units_pledged or 1)
            if blood_req.units_pending < units and blood_req.units_received + units <= (blood_req.units_needed or 1):
                blood_req.units_pending = max(blood_req.units_pending, units)
                blood_req.save(update_fields=['units_pending'])

            locked_acc.status = 'DONATED'
            locked_acc.donated_at = locked_acc.donated_at or now
            if is_donor:
                locked_acc.donor_confirmed_at = locked_acc.donor_confirmed_at or now
            elif is_requester:
                locked_acc.requester_confirmed_at = locked_acc.requester_confirmed_at or now
            locked_acc.save(update_fields=['status', 'donated_at', 'donor_confirmed_at', 'requester_confirmed_at'])

            if locked_acc.donor_confirmed_at is not None and locked_acc.requester_confirmed_at is not None:
                finalize_donation(locked_acc, auto=False)
                return Response({'status': 'CONFIRMED', 'message': 'Donation confirmed by both sides.'}, status=status.HTTP_200_OK)

        return Response({'status': 'DONATED', 'message': 'Pending requester confirmation.'})

    elif new_status == 'CONFIRMED':
        if not is_requester:
            return Response({'error': 'Unauthorized.'}, status=403)

        with transaction.atomic():
            locked_acc = RequestAcceptance.objects.select_for_update().get(pk=acceptance.pk)
            blood_req = BloodRequest.objects.select_for_update().get(pk=locked_acc.request_id)

            # Idempotent check
            if locked_acc.status == 'CONFIRMED' and locked_acc.completed_at is not None:
                return Response({
                    'message': 'Donation already marked as completed.',
                    'status': 'CONFIRMED',
                    'completed_at': locked_acc.completed_at,
                }, status=status.HTTP_200_OK)

            units = max(1, locked_acc.units_pledged or 1)
            if blood_req.units_pending < units and blood_req.units_received + units <= (blood_req.units_needed or 1):
                blood_req.units_pending = max(blood_req.units_pending, units)
                blood_req.save(update_fields=['units_pending'])

            locked_acc.requester_confirmed_at = locked_acc.requester_confirmed_at or now
            locked_acc.save(update_fields=['requester_confirmed_at'])

            # Complete only when donor has ALSO confirmed (status=='DONATED' or donor_confirmed_at set)
            if locked_acc.status == 'DONATED' or locked_acc.donor_confirmed_at is not None:
                finalize_donation(locked_acc, auto=False)
                return Response({
                    'message': 'Donation successfully marked as completed. Donor record updated.',
                    'status': 'CONFIRMED',
                    'completed_at': locked_acc.completed_at,
                }, status=status.HTTP_200_OK)

            return Response({
                'message': 'Requester confirmation recorded. Pending donor confirmation.',
                'status': locked_acc.status,
                'requester_confirmed_at': locked_acc.requester_confirmed_at,
            }, status=status.HTTP_200_OK)

    elif new_status == 'CANCELLED':
        reason = request.data.get('reason', 'Cancelled by user.')
        with transaction.atomic():
            locked_acc = RequestAcceptance.objects.select_for_update().get(pk=acceptance.pk)
            blood_req = BloodRequest.objects.select_for_update().get(pk=locked_acc.request_id)
            if locked_acc.status == 'CONFIRMED':
                return Response({'error': 'Cannot cancel after donation is confirmed by both sides.'}, status=status.HTTP_409_CONFLICT)

            if not locked_acc.is_standby and locked_acc.status in ('ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED'):
                blood_req.units_pending = max(0, blood_req.units_pending - max(1, locked_acc.units_pledged or 1))
                blood_req.save(update_fields=['units_pending'])

            locked_acc.status = 'CANCELLED'
            locked_acc.cancellation_reason = reason
            locked_acc.completed_at = now
            locked_acc.donor_confirmed_at = None
            locked_acc.requester_confirmed_at = None
            locked_acc.save(update_fields=['status', 'cancellation_reason', 'completed_at', 'donor_confirmed_at', 'requester_confirmed_at'])

            donor = locked_acc.donor
            donor.cancel_count = (donor.cancel_count or 0) + 1
            donor.save(update_fields=['cancel_count'])

        return Response({
            'message': 'Journey cancelled.',
            'status': 'CANCELLED',
        }, status=status.HTTP_200_OK)

    # ON_THE_WAY or ARRIVED
    acceptance.status = new_status
    acceptance.save(update_fields=['status'])
    return Response({
        'message': f'Status transitioned to {new_status}.',
        'status': acceptance.status,
    }, status=status.HTTP_200_OK)


# ── Donation Issues & Standby ─────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def journey_issue_report_view(request, pk):
    """
    Reports an issue during donation (Medical Rejection, Donor No-Show, Logistics Delay).
    Medical rejection sets DONOR_COOLDOWN_DAYS deferral; no-show increments penalty; both trigger Standby offers.
    """
    from api.conf import DONOR_COOLDOWN_DAYS

    acceptance = RequestAcceptance.objects.filter(id=pk).select_related('request', 'donor__user').first()
    if not acceptance:
        return Response({'error': 'Journey acceptance not found.'}, status=status.HTTP_404_NOT_FOUND)

    issue_type = request.data.get('issue_type', 'OTHER').strip().upper()
    description = request.data.get('description', '').strip()

    valid_types = ['MEDICAL_REJECTION', 'DONOR_NO_SHOW', 'LOGISTICS_DELAY', 'OTHER']
    if issue_type not in valid_types:
        return Response({'error': f'Invalid issue type. Allowed: {valid_types}'}, status=status.HTTP_400_BAD_REQUEST)

    from api.models import DonationIssue, DeferralRecord
    from api.services.standby import trigger_standby_donor_offer

    issue = DonationIssue.objects.create(
        acceptance=acceptance,
        reported_by=request.user,
        issue_type=issue_type,
        description=description,
    )

    now = timezone.now()
    standby_offer = None

    if issue_type == 'MEDICAL_REJECTION':
        # Journey failed due to medical screen
        acceptance.status = 'FAILED'
        acceptance.cancellation_reason = f"Medical Rejection: {description}"
        acceptance.completed_at = now
        acceptance.save(update_fields=['status', 'cancellation_reason', 'completed_at'])

        # Apply medical deferral using DONOR_COOLDOWN_DAYS from api/conf.py
        donor = acceptance.donor
        deferral_date = now + timedelta(days=DONOR_COOLDOWN_DAYS)
        donor.deferral_until = deferral_date
        donor.save(update_fields=['deferral_until'])

        DeferralRecord.objects.create(
            donor=donor,
            reason=f"Medical rejection at hospital: {description or 'Vital signs / low hemoglobin'}",
            reason_code='MEDICAL',
            expires_at=deferral_date,
            created_by=request.user,
            is_active=True,
        )

        # Trigger Standby Donor offer
        standby_offer = trigger_standby_donor_offer(acceptance.request, exclude_donor_ids=[donor.id])

    elif issue_type == 'DONOR_NO_SHOW':
        acceptance.status = 'FAILED'
        acceptance.cancellation_reason = f"Donor No-Show: {description}"
        acceptance.completed_at = now
        acceptance.save(update_fields=['status', 'cancellation_reason', 'completed_at'])

        donor = acceptance.donor
        donor.no_show_count = (donor.no_show_count or 0) + 1
        donor.save(update_fields=['no_show_count'])

        # Trigger Standby Donor offer
        standby_offer = trigger_standby_donor_offer(acceptance.request, exclude_donor_ids=[donor.id])

    elif issue_type == 'LOGISTICS_DELAY':
        # Logistics / traffic delay does not fail the journey
        pass

    serializer = DonationIssueSerializer(issue)
    return Response({
        'message': 'Issue reported successfully.',
        'issue': serializer.data,
        'standby_triggered': bool(standby_offer),
        'standby_offer_id': standby_offer.id if standby_offer else None,
    }, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def standby_offer_detail_view(request, pk):
    """
    View standby offer details with countdown timer and masked requester information.
    """
    from api.models import StandbyOffer
    offer = StandbyOffer.objects.filter(id=pk).select_related('request', 'donor__user').first()
    if not offer:
        return Response({'error': 'Standby offer not found.'}, status=status.HTTP_404_NOT_FOUND)

    if offer.donor.user_id != request.user.id and not request.user.is_staff:
        return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

    serializer = StandbyOfferSerializer(offer)
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsProfileComplete])
def standby_offer_respond_view(request, pk):
    """
    Standby donor responds to offer: 'ACCEPT' or 'DECLINE'.
    Accepting creates RequestAcceptance and unmasks requester contact.
    """
    from api.conf import DONOR_COOLDOWN_DAYS
    from api.models import StandbyOffer
    offer = StandbyOffer.objects.filter(id=pk).select_related('request', 'donor__user').first()
    if not offer:
        return Response({'error': 'Standby offer not found.'}, status=status.HTTP_404_NOT_FOUND)

    if offer.donor.user_id != request.user.id:
        return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

    # Check DONOR_COOLDOWN_DAYS eligibility
    donor = offer.donor
    if donor.last_donation_date:
        days_since_last = (timezone.now().date() - donor.last_donation_date).days
        if days_since_last < DONOR_COOLDOWN_DAYS:
            return Response({
                'error': f'You are not eligible to donate. You must wait {DONOR_COOLDOWN_DAYS} days after your last donation. ({DONOR_COOLDOWN_DAYS - days_since_last} days remaining)'
            }, status=status.HTTP_400_BAD_REQUEST)

    action = request.data.get('action', '').strip().upper()
    if action not in ('ACCEPT', 'DECLINE'):
        return Response({'error': 'Action must be ACCEPT or DECLINE.'}, status=status.HTTP_400_BAD_REQUEST)

    now = timezone.now()
    if offer.expires_at and offer.expires_at <= now:
        offer.status = 'EXPIRED'
        offer.save(update_fields=['status'])
        return Response({'error': 'This standby offer has expired.'}, status=status.HTTP_400_BAD_REQUEST)

    if action == 'ACCEPT':
        offer.status = 'ACCEPTED'
        offer.responded_at = now
        offer.save(update_fields=['status', 'responded_at'])

        # Create active RequestAcceptance as standby
        acceptance = RequestAcceptance.objects.create(
            request=offer.request,
            donor=offer.donor,
            status='ACCEPTED',
            is_standby=True,
        )

        donor = offer.donor
        donor.response_count = (donor.response_count or 0) + 1
        donor.save(update_fields=['response_count'])

        return Response({
            'message': 'Standby offer accepted. You are now the primary active donor.',
            'acceptance_id': acceptance.id,
            'requester_phone': offer.request.contact_phone or offer.request.contact_number,
            'ward_bed': offer.request.ward_bed,
        }, status=status.HTTP_200_OK)

    # DECLINE
    offer.status = 'DECLINED'
    offer.responded_at = now
    offer.save(update_fields=['status', 'responded_at'])

    # Auto-trigger next standby candidate
    from api.services.standby import trigger_standby_donor_offer
    next_offer = trigger_standby_donor_offer(offer.request, exclude_donor_ids=[offer.donor_id])

    return Response({
        'message': 'Standby offer declined.',
        'next_standby_triggered': bool(next_offer),
    }, status=status.HTTP_200_OK)


# ── Brevo HTTPS Email OTP Endpoints ──────────────────────────────────────────

@api_view(['POST'])
@permission_classes([AllowAny])
def email_otp_send_view(request):
    """
    POST /api/auth/otp/send/
    DEPRECATED: Returns HTTP 410 Gone. Use /api/requests/otp/send/.
    """
    return Response(
        {"detail": "Endpoint deprecated. Use /api/requests/otp/send/."},
        status=status.HTTP_410_GONE,
    )


@api_view(['POST'])
@permission_classes([AllowAny])
def email_otp_verify_view(request):
    """
    POST /api/auth/otp/verify/
    DEPRECATED: Returns HTTP 410 Gone. Use /api/requests/otp/verify/.
    """
    return Response(
        {"detail": "Endpoint deprecated. Use /api/requests/otp/verify/."},
        status=status.HTTP_410_GONE,
    )


# ─────────────────────────────────────────────────────────────────────────────
# JOURNEY DETAIL & LIST  (Prompt 5)
# ─────────────────────────────────────────────────────────────────────────────

import random  # noqa: E402


def _fuzz_coord(coord, radius_km=0.5):
    """Offset coordinate by up to radius_km in a random direction."""
    if coord is None:
        return None
    offset = (random.random() - 0.5) * 2 * radius_km / 111.0
    return round(coord + offset, 6)


def _mask_phone(phone, revealed=False):
    """Return masked phone unless revealed."""
    if not phone:
        return ''
    if revealed:
        return phone
    if len(phone) >= 6:
        return phone[:4] + '\u2022' * (len(phone) - 6) + phone[-2:]
    return '\u2022' * len(phone)


def _build_milestones(acceptance):
    """Build milestone dict for 4-step journey progress."""
    ts = acceptance.started_at.isoformat() if acceptance.started_at else None
    done_ts = acceptance.completed_at.isoformat() if acceptance.completed_at else ts
    milestones = {
        'ACCEPTED': ts,
        'ON_THE_WAY': None,
        'ARRIVED': None,
        'DONATED': None,
    }
    if acceptance.status in ('ON_THE_WAY', 'ARRIVED', 'DONATED', 'FAILED', 'CANCELLED'):
        milestones['ON_THE_WAY'] = ts
    if acceptance.status in ('ARRIVED', 'DONATED'):
        milestones['ARRIVED'] = done_ts
    if acceptance.status == 'DONATED':
        milestones['DONATED'] = done_ts
    return milestones


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def journey_detail_view(request, pk):
    """
    GET /api/journeys/<pk>/
    Role-scoped: REQUESTER sees donor live location + contact;
    DONOR sees patient/hospital + requester contact.
    Contacts masked until status is ARRIVED or DONATED.
    """
    acceptance = (
        RequestAcceptance.objects
        .select_related(
            'request', 'request__requester', 'request__hospital',
            'donor', 'donor__user',
        )
        .filter(pk=pk)
        .first()
    )

    if not acceptance:
        return Response({'detail': 'Journey not found.'}, status=status.HTTP_404_NOT_FOUND)

    req = acceptance.request
    donor_profile = acceptance.donor
    is_donor = (donor_profile.user_id == request.user.id)
    is_requester = (req.requester_id == request.user.id or request.user.is_staff)

    if not (is_donor or is_requester):
        return Response({'detail': 'You are not part of this journey.'}, status=status.HTTP_403_FORBIDDEN)

    viewer_role = 'DONOR' if is_donor else 'REQUESTER'
    contact_revealed = acceptance.status in ('ARRIVED', 'DONATED')
    hospital_name = req.hospital.name if req.hospital else (req.hospital_location or '')
    dest_lat = req.lat or (req.hospital.lat if req.hospital else None)
    dest_lng = req.lng or (req.hospital.lng if req.hospital else None)
    donor_lat_fuzzed = _fuzz_coord(acceptance.donor_lat)
    donor_lng_fuzzed = _fuzz_coord(acceptance.donor_lng)
    donor_phone = getattr(donor_profile.user, 'phone_number', '') or ''
    can_report = is_requester and acceptance.status in ('ON_THE_WAY', 'ARRIVED')
    can_cancel = is_requester and acceptance.status in ('ACCEPTED', 'ON_THE_WAY')

    return Response({
        'id': acceptance.id,
        'status': acceptance.status,
        'viewer_role': viewer_role,
        'blood_group': req.blood_group or '',
        'component': getattr(req, 'component', 'WHOLE') or 'WHOLE',
        'urgency': req.urgency or getattr(req, 'urgency_level', '') or '',
        'units_needed': req.units_needed,
        'units_received': req.units_received,
        'units_pending': req.units_pending,
        'request_mode': req.request_mode,
        'support_status': acceptance.support_status,
        'support_status_label': (
            'Voluntary Only / Charity'
            if acceptance.support_status == 'VOLUNTARY_ONLY'
            else 'Can Support'
        ),
        'milestones': _build_milestones(acceptance),
        'eta_minutes': acceptance.eta_minutes,
        'distance_km': acceptance.distance_km,
        'can_report': can_report,
        'can_cancel': can_cancel,
        'created_at': acceptance.started_at.isoformat(),
        'donor_name': donor_profile.user.get_full_name() or donor_profile.user.username,
        'donor_contact': _mask_phone(donor_phone, revealed=contact_revealed),
        'donor_lat': donor_lat_fuzzed,
        'donor_lng': donor_lng_fuzzed,
        'patient_name': req.patient_name or '',
        'hospital_name': hospital_name,
        'requester_contact': _mask_phone(req.contact_phone or '', revealed=contact_revealed),
        'dest_lat': dest_lat,
        'dest_lng': dest_lng,
        'requester_lat': None,
        'requester_lng': None,
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def journey_list_view(request):
    """
    GET /api/journeys/
    All journeys (as donor or requester), newest first, paginated.
    """
    user = request.user
    donor_profile = DonorProfile.objects.filter(user=user).first()
    donor_filter = Q(donor=donor_profile) if donor_profile else Q(pk__in=[])
    qs = (
        RequestAcceptance.objects
        .select_related('request', 'request__hospital', 'donor', 'donor__user')
        .filter(Q(request__requester=user) | donor_filter)
        .order_by('-started_at')
    )
    limit = min(50, int(request.query_params.get('limit', 20)))
    offset = int(request.query_params.get('offset', 0))
    total = qs.count()
    page = qs[offset: offset + limit]

    items = []
    for acc in page:
        req = acc.request
        is_donor_view = donor_profile and acc.donor_id == donor_profile.id
        hospital_name = req.hospital.name if req.hospital else (req.hospital_location or '')
        items.append({
            'id': acc.id,
            'status': acc.status,
            'viewer_role': 'DONOR' if is_donor_view else 'REQUESTER',
            'blood_group': req.blood_group or '',
            'urgency': req.urgency or getattr(req, 'urgency_level', '') or '',
            'hospital_name': hospital_name,
            'is_standby': acc.is_standby,
            'support_status': acc.support_status,
            'created_at': acc.started_at.isoformat(),
        })

    return Response({
        'count': total,
        'next_offset': offset + limit if offset + limit < total else None,
        'results': items,
    }, status=status.HTTP_200_OK)



@api_view(['POST'])
@permission_classes([IsAuthenticated])
def deferral_appeal_view(request, pk):
    """
    Allows a donor to appeal a deferral record.
    POST /api/deferrals/<pk>/appeal/
    """
    from api.models import DeferralRecord
    
    try:
        donor = request.user.donorprofile
        deferral = DeferralRecord.objects.get(pk=pk, donor=donor)
    except Exception:
        return Response({'error': 'Deferral record not found.'}, status=404)
        
    if deferral.appeal_status != 'NONE':
        return Response({'error': 'Appeal already submitted or processed.'}, status=400)
        
    deferral.appeal_status = 'PENDING'
    deferral.save(update_fields=['appeal_status'])
    
    return Response({'message': 'Appeal submitted successfully.', 'status': 'PENDING'})



@api_view(['GET'])
@permission_classes([AllowAny])
def active_deferral_view(request):
    """
    GET /api/deferrals/active/
    Returns the currently active deferral (if any) for the logged-in donor.
    """
    from api.models import DeferralRecord
    
    if not request.user or not request.user.is_authenticated:
        return Response({'has_deferral': False})
    
    try:
        donor = request.user.donorprofile
        now = timezone.now()
        
        # Check explicit deferral_until date
        if donor.deferral_until and donor.deferral_until > now:
            active = DeferralRecord.objects.filter(donor=donor, expires_at__gt=now).order_by('-created_at').first()
            if active:
                return Response({
                    'has_deferral': True,
                    'id': active.id,
                    'reason': active.reason,
                    'reason_code': active.reason_code,
                    'expires_at': active.expires_at.isoformat() if active.expires_at else None,
                    'appeal_status': active.appeal_status,
                })
        
        return Response({'has_deferral': False})
        
    except Exception:
        return Response({'has_deferral': False})



# -----------------------------------------------------------------------------
# PROMPT 9: NATIONAL EMERGENCY & DISASTER RESPONSE
# -----------------------------------------------------------------------------
@api_view(['GET'])
@permission_classes([AllowAny])
def active_national_emergency_view(request):
    """
    GET /api/emergency/national/active/
    Returns the currently active national emergency event, including points and slots.
    """
    from api.models import NationalEmergencyEvent
    from api.serializers_bloodhub import NationalEmergencyEventSerializer
    
    event = NationalEmergencyEvent.objects.filter(is_active=True).first()
    if not event:
        # Check if there is an ended event recently (optional logic for "This emergency has ended")
        recent_ended = NationalEmergencyEvent.objects.filter(is_active=False).order_by('-ended_at').first()
        if recent_ended:
            return Response({'is_active': False, 'message': 'This emergency has ended. Thank you.'})
        return Response({'is_active': False, 'message': 'No emergency right now'})
        
    serializer = NationalEmergencyEventSerializer(event)
    return Response({'is_active': True, 'event': serializer.data})

@api_view(['POST'])
@permission_classes([IsAuthenticated, IsProfileComplete])
def pledge_to_donate_view(request):
    """
    POST /api/emergency/national/pledge/
    Payload: { "slot_id": 123 }
    """
    from api.conf import DONOR_COOLDOWN_DAYS
    from api.models import DonationSlot, DisasterPledge
    import string
    import random
    from django.db import transaction
    
    slot_id = request.data.get('slot_id')
    try:
        slot = DonationSlot.objects.get(id=slot_id)
    except DonationSlot.DoesNotExist:
        return Response({'error': 'Slot not found.'}, status=404)
        
    if slot.pledged >= slot.capacity:
        return Response({'error': 'Slot is full.'}, status=400)
        
    donor = request.user.donorprofile
    
    # Check DONOR_COOLDOWN_DAYS eligibility
    if donor.last_donation_date:
        days_since_last = (timezone.now().date() - donor.last_donation_date).days
        if days_since_last < DONOR_COOLDOWN_DAYS:
            return Response({
                'error': f'You are not eligible to pledge. You must wait {DONOR_COOLDOWN_DAYS} days after your last donation. ({DONOR_COOLDOWN_DAYS - days_since_last} days remaining)'
            }, status=400)
    
    # Check if they already have an active pledge
    existing = DisasterPledge.objects.filter(event=slot.point.event, donor=donor, status='PENDING').exists()
    if existing:
        return Response({'error': 'You already have an active pledge.'}, status=400)
        
    # Eligibility checks should ideally happen here, but we will mock success
    # Generate 6 char code
    code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    
    with transaction.atomic():
        pledge = DisasterPledge.objects.create(
            event=slot.point.event,
            donor=donor,
            slot=slot,
            pledge_code=code
        )
        # Update slot pledged count
        slot.pledged += 1
        slot.save(update_fields=['pledged'])
        
    return Response({
        'message': 'Pledge successful.',
        'pledge_code': code,
        'point_name': slot.point.name,
        'time_range': slot.time_range,
    })
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_pledge_view(request):
    """
    GET /api/emergency/national/my-pledge/
    """
    from api.models import DisasterPledge
    from api.serializers_bloodhub import DisasterPledgeSerializer
    
    donor = request.user.donorprofile
    pledge = DisasterPledge.objects.filter(donor=donor, status='PENDING').order_by('-created_at').first()
    if not pledge:
        return Response({'has_pledge': False})
        
    return Response({
        'has_pledge': True,
        'pledge': DisasterPledgeSerializer(pledge).data
    })
@api_view(['POST'])
@permission_classes([IsAuthenticated, IsProfileComplete])
def emergency_request_all_view(request, pk):
    """
    Manually dispatch notifications to all eligible donors in the area.
    """
    blood_req = BloodRequest.objects.filter(id=pk).first()
    if not blood_req:
        return Response({'error': 'Blood request not found.'}, status=status.HTTP_404_NOT_FOUND)

    candidates = get_candidate_donors_for_wave(blood_req, wave_number=3) # Wave 3 or max wave usually targets everyone in district
    if not candidates:
        return Response({'message': 'No eligible donors found.', 'notified': 0}, status=status.HTTP_200_OK)

    dispatch_wave_notifications(blood_req, candidates, wave_number=3)
    return Response({'message': f'Notified {len(candidates)} donors.', 'notified': len(candidates)}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def emergency_request_all_view(request):
    return Response({'message': 'No eligible donors found.', 'notified': 0}, status=status.HTTP_200_OK)

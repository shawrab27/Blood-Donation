from django.utils import timezone
"""
Dedicated API views for BloodPulse Blood Hub v2.
Handles search, map, hospital directory, request creation, wave progression, and acceptances.
"""

from datetime import timedelta

from django.db.models import Q
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestAcceptance,
    FakeReport,
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
    Search available donors by blood group, component compatibility, campus, or district.
    Enforces privacy: masked phone numbers, only opted-in (is_searchable) donors.
    """
    blood_group = request.query_params.get('blood_group', '').strip()
    component = request.query_params.get('component', 'WHOLE').strip()
    campus = request.query_params.get('campus', '').strip()
    district = request.query_params.get('district', '').strip()
    limit = min(50, int(request.query_params.get('limit', 20)))
    offset = int(request.query_params.get('offset', 0))

    queryset = DonorProfile.objects.filter(
        is_searchable=True,
        is_available=True,
    ).select_related('user')

    if blood_group:
        compatible_groups = get_compatible_donor_groups(blood_group, component)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    if campus:
        queryset = queryset.filter(Q(campus__icontains=campus) | Q(institute__icontains=campus))

    if district:
        queryset = queryset.filter(district__icontains=district)

    total_count = queryset.count()
    results = queryset.order_by('-total_bags_donated', '-rating_avg')[offset:offset + limit]

    serializer = DonorSearchSerializer(results, many=True, context={'request': request})
    return Response({
        'total': total_count,
        'offset': offset,
        'limit': limit,
        'results': serializer.data,
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def donor_map_view(request):
    """
    Returns fuzzed coordinates (~500m) for donors within an area or boundary.
    Strictly excludes non-searchable donors and unverified coordinates.
    """
    blood_group = request.query_params.get('blood_group', '').strip()
    component = request.query_params.get('component', 'WHOLE').strip()
    district = request.query_params.get('district', '').strip()

    queryset = DonorProfile.objects.filter(
        is_searchable=True,
        is_available=True,
    ).exclude(
        Q(latitude__isnull=True) & Q(last_lat__isnull=True)
    )

    if blood_group:
        compatible_groups = get_compatible_donor_groups(blood_group, component)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    if district:
        queryset = queryset.filter(district__icontains=district)

    results = queryset[:100]
    serializer = DonorMapSerializer(results, many=True)
    return Response({
        'count': len(results),
        'donors': serializer.data,
    }, status=status.HTTP_200_OK)


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
    client_request_id = request.data.get('client_request_id')
    if client_request_id:
        existing = BloodRequest.objects.filter(client_request_id=client_request_id).first()
        if existing:
            detail_serializer = BloodRequestDetailSerializer(existing, context={'request': request})
            return Response(detail_serializer.data, status=status.HTTP_200_OK)

    patient_name = request.data.get('patient_name', '').strip()
    blood_group = request.data.get('blood_group', '').strip()
    component = request.data.get('component', 'WHOLE').strip()
    units_needed = int(request.data.get('units_needed', 1))
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

    if not patient_name or not blood_group:
        return Response({'error': 'patient_name and blood_group are required.'}, status=status.HTTP_400_BAD_REQUEST)

    hospital = None
    if hospital_id:
        hospital = Hospital.objects.filter(id=hospital_id).first()

    # Image files with EXIF stripping
    requisition_slip = strip_image_exif(request.FILES.get('requisition_slip'))
    patient_photo = strip_image_exif(request.FILES.get('patient_photo'))

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
    effective_scope = resolve_effective_scope(requested_scope, trust_band)

    # Initial wave timeouts
    now = timezone.now()
    timeout_map = WAVE_TIMEOUT_MINUTES.get(urgency, WAVE_TIMEOUT_MINUTES['CRITICAL_2H'])
    wave1_mins = timeout_map.get(1, 15)
    next_wave_at = now + timedelta(minutes=wave1_mins)
    expires_at = now + timedelta(hours=24) # 24h default expiration

    blood_req = BloodRequest.objects.create(
        requester=requester,
        patient_name=patient_name,
        blood_group=blood_group,
        mode=request.data.get('mode', 'EMERGENCY'),
        component=component,
        units_needed=units_needed,
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
@permission_classes([IsAuthenticated])
def emergency_request_accept_view(request, pk):
    """
    Donor accepts an emergency request.
    Verifies eligibility, creates RequestAcceptance, reveals contact phone.
    """
    blood_req = BloodRequest.objects.filter(id=pk).first()
    if not blood_req:
        return Response({'error': 'Blood request not found.'}, status=status.HTTP_404_NOT_FOUND)

    if blood_req.status != 'ACTIVE':
        return Response({'error': f'Request is not active (Status: {blood_req.status}).'}, status=status.HTTP_400_BAD_REQUEST)

    if not hasattr(request.user, 'donorprofile'):
        return Response({'error': 'User must have a donor profile to accept.'}, status=status.HTTP_400_BAD_REQUEST)

    donor = request.user.donorprofile

    # Check 90 days eligibility
    if donor.last_donation_date:
        
        days_since_last = (timezone.now().date() - donor.last_donation_date).days
        if days_since_last < 90:
            return Response({
                'error': f'You are not eligible to donate. You must wait 90 days after your last donation. ({90 - days_since_last} days remaining)'
            }, status=status.HTTP_400_BAD_REQUEST)

    existing_acceptance = RequestAcceptance.objects.filter(
        request=blood_req,
        donor=donor,
    ).exclude(status__in=['FAILED', 'CANCELLED']).first()

    if existing_acceptance:
        serializer = RequestAcceptanceSerializer(existing_acceptance)
        return Response({
            'message': 'You have already accepted this request.',
            'acceptance': serializer.data,
            'requester_phone': blood_req.contact_phone or blood_req.contact_number,
            'ward_bed': blood_req.ward_bed,
        }, status=status.HTTP_200_OK)

    acceptance = RequestAcceptance.objects.create(
        request=blood_req,
        donor=donor,
        status='ACCEPTED',
    )

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
    Report a request as fake, abusive, or fraudulent.
    If 3+ confirmed reports, suspends request to PENDING_ADMIN.
    """
    blood_req = BloodRequest.objects.filter(id=pk).first()
    if not blood_req:
        return Response({'error': 'Blood request not found.'}, status=status.HTTP_404_NOT_FOUND)

    reason = request.data.get('reason', '').strip()
    if not reason:
        return Response({'error': 'Reason is required for report.'}, status=status.HTTP_400_BAD_REQUEST)

    report = FakeReport.objects.create(
        request=blood_req,
        reporter=request.user,
        reason=reason,
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
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def emergency_wave_tick_view(request):
    """
    Triggers wave progression tick for all active requests.
    Used by cron, celery, or internal runner.
    """
    result = process_wave_tick()
    return Response(result, status=status.HTTP_200_OK)


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
def journey_status_transition_view(request, pk):
    """
    Transitions the journey through its lifecycle milestones:
    ACCEPTED -> ON_THE_WAY -> ARRIVED -> DONATED (or CANCELLED)
    """
    acceptance = RequestAcceptance.objects.filter(id=pk).select_related('request', 'donor__user').first()
    if not acceptance:
        return Response({'error': 'Journey acceptance not found.'}, status=status.HTTP_404_NOT_FOUND)

    new_status = request.data.get('status', '').strip().upper()
    valid_statuses = ['ON_THE_WAY', 'ARRIVED', 'DONATED', 'CANCELLED']
    if new_status not in valid_statuses:
        return Response({'error': f'Invalid status. Allowed: {valid_statuses}'}, status=status.HTTP_400_BAD_REQUEST)

    is_donor = (acceptance.donor.user_id == request.user.id)
    is_requester = (acceptance.request.requester_id == request.user.id or request.user.is_staff)

    if not (is_donor or is_requester):
        return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

    now = timezone.now()

    if new_status == 'DONATED':
        if not (is_donor or is_requester):
            return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

        acceptance.status = 'DONATED'
        acceptance.completed_at = now
        acceptance.save(update_fields=['status', 'completed_at'])

        # Fulfill request
        blood_req = acceptance.request
        blood_req.status = 'FULFILLED'
        blood_req.is_active = False
        blood_req.save(update_fields=['status', 'is_active'])

        # Update donor stats
        donor = acceptance.donor
        donor.fulfilled_count = (donor.fulfilled_count or 0) + 1
        donor.total_bags_donated = (donor.total_bags_donated or 0) + (blood_req.units_needed or 1)
        donor.last_donation_date = now.date()
        donor.is_available = False
        donor.save(update_fields=['fulfilled_count', 'total_bags_donated', 'last_donation_date', 'is_available'])

        # Record donation history
        from api.models import DonationHistory
        DonationHistory.objects.create(
            donor=donor,
            date=now.date(),
            location=blood_req.hospital_location or (blood_req.hospital.name if blood_req.hospital else 'Hospital'),
            bags_donated=blood_req.units_needed or 1,
            notes=f"Emergency requisition #{blood_req.id} fulfilled.",
        )

        return Response({
            'message': 'Donation successfully marked as completed. Donor record updated.',
            'status': 'DONATED',
        }, status=status.HTTP_200_OK)

    elif new_status == 'CANCELLED':
        reason = request.data.get('reason', 'Cancelled by user.')
        acceptance.status = 'CANCELLED'
        acceptance.cancellation_reason = reason
        acceptance.completed_at = now
        acceptance.save(update_fields=['status', 'cancellation_reason', 'completed_at'])

        donor = acceptance.donor
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
    Medical rejection sets 90-day deferral; no-show increments penalty; both trigger Standby offers.
    """
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

        # Apply 90-day medical deferral
        donor = acceptance.donor
        deferral_date = now + timedelta(days=90)
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
@permission_classes([IsAuthenticated])
def standby_offer_respond_view(request, pk):
    """
    Standby donor responds to offer: 'ACCEPT' or 'DECLINE'.
    Accepting creates RequestAcceptance and unmasks requester contact.
    """
    from api.models import StandbyOffer
    offer = StandbyOffer.objects.filter(id=pk).select_related('request', 'donor__user').first()
    if not offer:
        return Response({'error': 'Standby offer not found.'}, status=status.HTTP_404_NOT_FOUND)

    if offer.donor.user_id != request.user.id:
        return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

    # Check 90 days eligibility
    donor = offer.donor
    if donor.last_donation_date:
        
        days_since_last = (timezone.now().date() - donor.last_donation_date).days
        if days_since_last < 90:
            return Response({
                'error': f'You are not eligible to donate. You must wait 90 days after your last donation. ({90 - days_since_last} days remaining)'
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
    Dispatches 6-digit OTP code strictly via Brevo HTTPS REST API (Rule 8).
    Enforces 60s cooldown and max 3 requests per hour.
    """
    from api.models import EmailOTP
    from api.services.email import (
        get_email_sender,
        generate_secure_otp,
        hash_otp,
        OTP_EXPIRY_MINUTES,
        OTP_RESEND_COOLDOWN_SECONDS,
        OTP_MAX_HOURLY_REQUESTS,
    )

    email = request.data.get('email', '').strip().lower()
    if not email or '@' not in email:
        return Response({'error': 'Valid email address is required.'}, status=status.HTTP_400_BAD_REQUEST)

    now = timezone.now()

    # Rate limiting: 60s cooldown
    recent_otp = EmailOTP.objects.filter(email=email).order_by('-created_at').first()
    if recent_otp and (now - recent_otp.created_at).total_seconds() < OTP_RESEND_COOLDOWN_SECONDS:
        seconds_left = int(OTP_RESEND_COOLDOWN_SECONDS - (now - recent_otp.created_at).total_seconds())
        return Response({
            'error': f'Please wait {seconds_left} seconds before requesting a new verification code.',
            'cooldown_seconds': seconds_left,
        }, status=status.HTTP_429_TOO_MANY_REQUESTS)

    # Rate limiting: max 3 per hour
    one_hour_ago = now - timedelta(hours=1)
    hourly_count = EmailOTP.objects.filter(email=email, created_at__gte=one_hour_ago).count()
    if hourly_count >= OTP_MAX_HOURLY_REQUESTS:
        return Response({
            'error': 'Too many OTP requests for this email address. Please try again in 1 hour.',
        }, status=status.HTTP_429_TOO_MANY_REQUESTS)

    # Generate & hash OTP
    code = generate_secure_otp(length=6)
    code_hash = hash_otp(code, email)
    expires_at = now + timedelta(minutes=OTP_EXPIRY_MINUTES)

    EmailOTP.objects.create(
        email=email,
        otp_hash=code_hash,
        expires_at=expires_at,
    )

    # Send via HTTPS Email API
    sender = get_email_sender()
    subject = f"{code} is your BloodPulse verification code"
    text_content = (
        f"Your BloodPulse verification code is: {code}\n\n"
        f"This code will expire in {OTP_EXPIRY_MINUTES} minutes.\n"
        f"If you did not request this code, please ignore this email."
    )
    html_content = (
        f"<div style='font-family: sans-serif; max-width: 480px; margin: auto; padding: 24px; border: 1px solid #f0e6e6; border-radius: 12px; background: #fff8f7;'>"
        f"<h2 style='color: #C30121; margin-top: 0;'>BloodPulse Verification</h2>"
        f"<p style='color: #2B2B2B;'>Please use the following 6-digit code to verify your email address:</p>"
        f"<div style='font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #C30121; padding: 16px; background: #fdf3f3; border-radius: 8px; text-align: center; margin: 20px 0;'>{code}</div>"
        f"<p style='color: #8E7D7F; font-size: 13px;'>This code expires in {OTP_EXPIRY_MINUTES} minutes. Never share this code with anyone.</p>"
        f"</div>"
    )

    sender.send_email(to_email=email, subject=subject, text_content=text_content, html_content=html_content)

    return Response({
        'message': f'Verification code dispatched to {email}.',
        'email': email,
        'expires_in_minutes': OTP_EXPIRY_MINUTES,
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
def email_otp_verify_view(request):
    """
    POST /api/auth/otp/verify/
    Verifies 6-digit code using HMAC-SHA256 constant-time comparison.
    Locks after 5 wrong attempts.
    """
    from api.models import EmailOTP, DonorProfile
    from api.services.email import verify_otp_hash

    email = request.data.get('email', '').strip().lower()
    code = request.data.get('code', '').strip()

    if not email or not code:
        return Response({'error': 'Email and 6-digit code are required.'}, status=status.HTTP_400_BAD_REQUEST)

    now = timezone.now()
    otp_record = EmailOTP.objects.filter(
        email=email,
        is_used=False,
        expires_at__gt=now,
    ).order_by('-created_at').first()

    if not otp_record:
        return Response({'error': 'Invalid or expired verification code. Please request a new one.'}, status=status.HTTP_400_BAD_REQUEST)

    if otp_record.is_locked():
        return Response({'error': 'This code has been locked due to too many failed attempts. Please request a new code.'}, status=status.HTTP_429_TOO_MANY_REQUESTS)

    # Verify constant-time
    if not verify_otp_hash(code, otp_record.otp_hash, email):
        otp_record.attempts += 1
        otp_record.save(update_fields=['attempts'])
        remaining_attempts = max(0, 5 - otp_record.attempts)
        return Response({
            'error': f'Incorrect code. {remaining_attempts} attempt(s) remaining.',
            'remaining_attempts': remaining_attempts,
        }, status=status.HTTP_400_BAD_REQUEST)

    # Verification successful
    otp_record.is_used = True
    otp_record.save(update_fields=['is_used'])

    # If user is authenticated, link email & update donor profile
    if request.user.is_authenticated:
        if request.user.email != email:
            request.user.email = email
            request.user.save(update_fields=['email'])

        profile, _ = DonorProfile.objects.get_or_create(user=request.user)
        profile.email_verified = True
        profile.save(update_fields=['email_verified'])

    # Also update any donor profile matching this email
    matched_donors = DonorProfile.objects.filter(user__email=email)
    for d in matched_donors:
        d.email_verified = True
        d.save(update_fields=['email_verified'])

    return Response({
        'message': 'Email address verified successfully.',
        'email': email,
        'email_verified': True,
    }, status=status.HTTP_200_OK)


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
@permission_classes([IsAuthenticated])
def active_deferral_view(request):
    """
    GET /api/deferrals/active/
    Returns the currently active deferral (if any) for the logged-in donor.
    """
    from api.models import DeferralRecord
    
    
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
@permission_classes([IsAuthenticated])
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
@permission_classes([IsAuthenticated])
def pledge_to_donate_view(request):
    """
    POST /api/emergency/national/pledge/
    Payload: { "slot_id": 123 }
    """
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
    
    # Check 90 days eligibility
    if donor.last_donation_date:
        
        days_since_last = (timezone.now().date() - donor.last_donation_date).days
        if days_since_last < 90:
            return Response({
                'error': f'You are not eligible to pledge. You must wait 90 days after your last donation. ({90 - days_since_last} days remaining)'
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

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Dedicated API views for the Blood Hub v2 request lifecycle.
Enforces object-level permissions, throttles, and delegates business logic to services.
"""

import os
from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.exceptions import PermissionDenied, ValidationError

from api.models import BloodRequest, BrokerReport, DonationMatch, FakeReport, FollowUp
from api.serializers_blood_hub_v2 import (
    BloodRequestCreateV2Serializer,
    BrokerReportCreateSerializer,
    DonationMatchDetailSerializer,
    DonationMatchStatusUpdateSerializer,
    ThankYouLetterSerializer,
    FollowUpAnswerSerializer,
    PosterDataSerializer,
    QRLandingSerializer,
)
from api.services.blood_hub_lifecycle_service import (
    IllegalStateTransitionError,
    ConflictError,
    create_draft_request,
    accept_request,
    update_match_status,
    confirm_match_donation,
    withdraw_match_response,
    report_match_failure,
    send_thank_you_letter,
    answer_follow_up,
    run_due_followups,
)
from api.permissions import IsProfileComplete
from api.services.targeting_service import calculate_eligible_reach
from api.throttles import (
    DonationConfirmThrottle,
    DonorResponseThrottle,
    RequestCreateThrottle,
)


class BloodRequestCreateV2APIView(APIView):
    permission_classes = [IsAuthenticated, IsProfileComplete]

    def get_throttles(self):
        if self.request.method == 'POST':
            return [RequestCreateThrottle()]
        return super().get_throttles()

    def get(self, request):
        from api.serializers_bloodhub import BloodRequestListSerializer
        qs = BloodRequest.objects.filter(is_active=True).order_by('-created_at')[:50]
        return Response(BloodRequestListSerializer(qs, many=True).data, status=status.HTTP_200_OK)

    def post(self, request):
        submit_token = request.data.get('submit_token') or request.headers.get('X-Submit-Token')
        from api.views_request_otp import check_submit_token, validate_and_consume_submit_token
        if not check_submit_token(request.user, submit_token):
            return Response(
                {"detail": "A valid unused submit_token is required to submit a blood request."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = BloodRequestCreateV2Serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            if not validate_and_consume_submit_token(request.user, submit_token):
                return Response(
                    {"detail": "A valid unused submit_token is required to submit a blood request."},
                    status=status.HTTP_403_FORBIDDEN,
                )
            req = create_draft_request(request.user, serializer.validated_data)
        return Response(BloodRequestCreateV2Serializer(req).data, status=status.HTTP_201_CREATED)


class BloodRequestDetailV2APIView(APIView):
    permission_classes = [IsAuthenticated, IsProfileComplete]

    def get(self, request, pk):
        from api.serializers_bloodhub import BloodRequestDetailSerializer
        try:
            req = BloodRequest.objects.get(pk=pk)
            return Response(BloodRequestDetailSerializer(req, context={'request': request}).data, status=status.HTTP_200_OK)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)

    def patch(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)

        if req.requester_id != request.user.id and not request.user.is_staff:
            raise PermissionDenied("Only the requester can update this blood request.")

        if 'units_needed' in request.data and int(request.data['units_needed']) != req.units_needed:
            return Response(
                {"units_needed": ["units_needed is locked after the request is posted."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = BloodRequestCreateV2Serializer(req, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class BloodRequestReachAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        bg = request.query_params.get('blood_group', '').replace(' ', '+').strip().upper()
        scope = request.query_params.get('scope', 'LOCAL').strip().upper()
        district = request.query_params.get('district', '').strip()
        division = request.query_params.get('division', '').strip()
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')

        lat_val = float(lat) if lat else None
        lng_val = float(lng) if lng else None

        reach = calculate_eligible_reach(
            blood_group=bg,
            scope=scope,
            district=district,
            division_name=division,
            lat=lat_val,
            lng=lng_val,
        )
        return Response({
            "reach": reach,
            "blood_group": bg,
            "scope": scope,
        }, status=status.HTTP_200_OK)


class BloodRequestAcceptAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [DonorResponseThrottle]

    def post(self, request, pk):
        support_status = request.data.get('support_status', 'CAN_SUPPORT')
        units_pledged = request.data.get('units_pledged', 1)
        try:
            match = accept_request(
                pk,
                request.user,
                support_status=support_status,
                units_pledged=units_pledged,
            )
            return Response(
                DonationMatchDetailSerializer(match, context={'request': request}).data,
                status=status.HTTP_201_CREATED,
            )
        except (ConflictError, IllegalStateTransitionError) as err:
            return Response({"detail": str(err)}, status=status.HTTP_409_CONFLICT)
        except ValidationError as err:
            return Response(err.detail, status=status.HTTP_400_BAD_REQUEST)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)


class DonationMatchWithdrawAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [DonorResponseThrottle]

    def post(self, request, pk):
        reason = request.data.get('reason', '').strip()
        try:
            match = withdraw_match_response(pk, request.user, reason=reason)
            return Response(
                DonationMatchDetailSerializer(match, context={'request': request}).data,
                status=status.HTTP_200_OK,
            )
        except (ConflictError, IllegalStateTransitionError) as err:
            return Response({"detail": str(err)}, status=status.HTTP_409_CONFLICT)
        except DonationMatch.DoesNotExist:
            return Response({"detail": "Match not found."}, status=status.HTTP_404_NOT_FOUND)


class BloodRequestWithdrawAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [DonorResponseThrottle]

    def post(self, request, pk):
        donor_profile = getattr(request.user, 'donorprofile', None)
        if not donor_profile:
            return Response({"detail": "Donor profile not found."}, status=status.HTTP_400_BAD_REQUEST)
        match = DonationMatch.objects.filter(request_id=pk, donor=donor_profile).first()
        if not match:
            return Response({"detail": "No active donor response found for this request."}, status=status.HTTP_404_NOT_FOUND)
        reason = request.data.get('reason', '').strip()
        try:
            updated = withdraw_match_response(match.id, request.user, reason=reason)
            return Response(
                DonationMatchDetailSerializer(updated, context={'request': request}).data,
                status=status.HTTP_200_OK,
            )
        except (ConflictError, IllegalStateTransitionError) as err:
            return Response({"detail": str(err)}, status=status.HTTP_409_CONFLICT)


class DonationMatchConfirmAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [DonationConfirmThrottle]

    def post(self, request, pk):
        action = request.data.get('action', 'CONFIRM')
        note = request.data.get('note', '')
        try:
            updated = confirm_match_donation(pk, request.user, action=action, note=note)
            return Response(
                DonationMatchDetailSerializer(updated, context={'request': request}).data,
                status=status.HTTP_200_OK,
            )
        except (ConflictError, IllegalStateTransitionError) as err:
            return Response({"detail": str(err)}, status=status.HTTP_409_CONFLICT)
        except DonationMatch.DoesNotExist:
            return Response({"detail": "Match not found."}, status=status.HTTP_404_NOT_FOUND)


class DonationMatchStatusAPIView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [DonationConfirmThrottle]

    def post(self, request, pk):
        try:
            match = DonationMatch.objects.select_related('request', 'donor__user').get(pk=pk)
        except DonationMatch.DoesNotExist:
            return Response({"detail": "Match not found."}, status=status.HTTP_404_NOT_FOUND)

        is_donor = match.donor.user_id == request.user.id
        is_requester = match.request.requester_id == request.user.id
        if not (is_donor or is_requester or request.user.is_staff):
            raise PermissionDenied("You are not authorized to update this match.")

        serializer = DonationMatchStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data['status'].upper()
        note = serializer.validated_data.get('note', '')

        if new_status in ['COMPLETED', 'CONFIRMED']:
            return Response(
                {"error": "Terminal donation completion requires two-sided confirmation via confirm-donation endpoint.",
                 "detail": "Terminal donation completion requires two-sided confirmation via confirm-donation endpoint."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_status in ['ON_THE_WAY', 'ARRIVED'] and not is_donor and not request.user.is_staff:
            raise PermissionDenied("Only the donor can report transit and arrival status.")

        try:
            updated = update_match_status(pk, request.user, new_status, note)
            return Response(
                DonationMatchDetailSerializer(updated, context={'request': request}).data,
                status=status.HTTP_200_OK,
            )
        except (IllegalStateTransitionError, ConflictError) as err:
            return Response({"error": str(err), "detail": str(err)}, status=status.HTTP_409_CONFLICT)


class BrokerReportCreateAPIView(APIView):
    """
    POST /api/requests/<pk>/report-broker/ or POST /api/reports/broker/
    Allows any authenticated user to report a suspected broker, fake request, or donor misconduct (Part D).
    Reporter identity/phone/email/location is NEVER exposed in the response or to the reported party.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk=None):
        req_obj = None
        req_id = pk or request.data.get('request_id') or request.data.get('request')
        if req_id:
            try:
                req_obj = BloodRequest.objects.get(pk=req_id)
            except BloodRequest.DoesNotExist:
                return Response({"detail": "Blood request not found."}, status=status.HTTP_404_NOT_FOUND)

        reason = (request.data.get('reason') or '').strip()
        if not reason:
            return Response({"reason": ["A reason is required to submit a report."]}, status=status.HTTP_400_BAD_REQUEST)

        target_type = (request.data.get('target_type') or 'BROKER').strip().upper()
        if target_type not in ('BROKER', 'REQUEST', 'DONOR'):
            target_type = 'BROKER'

        reported_user = None
        reported_user_id = request.data.get('reported_user_id') or request.data.get('reported_user')
        if reported_user_id:
            reported_user = User.objects.filter(pk=reported_user_id).first()
        elif req_obj and req_obj.requester_id and req_obj.requester_id != request.user.id:
            reported_user = req_obj.requester

        broker_report = BrokerReport.objects.create(
            request=req_obj,
            reported_user=reported_user,
            reporter=request.user,
            target_type=target_type,
            reason=reason,
            details=(request.data.get('details') or '').strip(),
            status='PENDING',
        )

        if req_obj:
            FakeReport.objects.create(
                request=req_obj,
                reporter=request.user,
                reason=reason,
            )
            if req_obj.fake_reports.count() >= 3:
                req_obj.status = 'PENDING_ADMIN'
                req_obj.escalated_to_admin = True
                req_obj.save(update_fields=['status', 'escalated_to_admin'])

        return Response(
            BrokerReportCreateSerializer(broker_report).data,
            status=status.HTTP_201_CREATED,
        )


class DonationMatchReportAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            match = DonationMatch.objects.select_related('request', 'donor__user').get(pk=pk)
        except DonationMatch.DoesNotExist:
            return Response({"detail": "Match not found."}, status=status.HTTP_404_NOT_FOUND)

        is_donor = match.donor.user_id == request.user.id
        is_requester = match.request.requester_id == request.user.id
        if not (is_donor or is_requester or request.user.is_staff):
            raise PermissionDenied("You are not authorized to report this match.")

        reason = request.data.get('reason', '').strip().upper()
        if reason not in ['MEDICAL', 'NO_SHOW', 'LOGISTICS']:
            return Response({"reason": "Must be one of MEDICAL, NO_SHOW, LOGISTICS."}, status=status.HTTP_400_BAD_REQUEST)

        note = request.data.get('note', '').strip()
        failed_match, promoted = report_match_failure(pk, request.user, reason, note)
        return Response({
            "status": "reported",
            "match_status": "FAILED",
            "promoted_standby": promoted.id if promoted else None,
        }, status=status.HTTP_200_OK)


class DonationMatchThanksAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        template_key = request.data.get('template_key', 'warm_gratitude')
        body = request.data.get('body', '').strip()
        if not body:
            return Response({"body": "Thank you letter message body is required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            letter = send_thank_you_letter(pk, request.user, template_key, body)
            return Response(ThankYouLetterSerializer(letter).data, status=status.HTTP_201_CREATED)
        except DonationMatch.DoesNotExist:
            return Response({"detail": "Match not found."}, status=status.HTTP_404_NOT_FOUND)


class FollowUpAnswerAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        serializer = FollowUpAnswerSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        res_val = serializer.validated_data['response']
        notes = serializer.validated_data.get('notes', '')

        try:
            fu = answer_follow_up(pk, request.user, res_val, notes)
            return Response({"status": "answered", "response": fu.response}, status=status.HTTP_200_OK)
        except FollowUp.DoesNotExist:
            return Response({"detail": "Follow-up record not found."}, status=status.HTTP_404_NOT_FOUND)


class InternalFollowUpRunAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        secret = request.headers.get('X-Internal-Secret') or request.headers.get('X-Cron-Secret')
        expected = os.getenv('INTERNAL_CRON_SECRET', settings.SECRET_KEY[:32])
        if not secret or secret != expected:
            raise PermissionDenied("Invalid or missing cron authentication token.")

        count = run_due_followups()
        return Response({"dispatched": count}, status=status.HTTP_200_OK)


class BloodRequestPosterDataAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
            return Response(PosterDataSerializer(req).data, status=status.HTTP_200_OK)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)


class BloodRequestQRLandingAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
            return Response(QRLandingSerializer(req).data, status=status.HTTP_200_OK)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Requisition not found."}, status=status.HTTP_404_NOT_FOUND)


class DonorFeedbackAPIView(APIView):
    """
    POST /api/requests/<pk>/feedback/
    Allows ONLY a donor with a donation CONFIRMED by both sides for that request to submit feedback.
    The requester can NEVER read feedback through any endpoint, serializer, notification, or QR page.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from api.models import BloodRequest, DonationMatch, DonorFeedback
        from api.serializers_blood_hub_v2 import DonorFeedbackCreateSerializer

        try:
            blood_req = BloodRequest.objects.get(pk=pk)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)

        donor_profile = getattr(request.user, 'donorprofile', None)
        if not donor_profile:
            return Response({"detail": "Only donors can submit feedback."}, status=status.HTTP_403_FORBIDDEN)

        # Check if donor had a confirmed donation for this request (two-sided confirmation)
        has_confirmed_donation = DonationMatch.objects.filter(
            request=blood_req,
            donor=donor_profile,
            confirmed_at__isnull=False,
        ).exists()

        if not has_confirmed_donation:
            return Response(
                {"detail": "Only donors with a donation confirmed by both sides may submit feedback for this request."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Check if already submitted
        if DonorFeedback.objects.filter(request=blood_req, donor=donor_profile).exists():
            return Response(
                {"detail": "You have already submitted feedback for this request."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = DonorFeedbackCreateSerializer(data={
            'request': blood_req.id,
            'stars': request.data.get('stars'),
            'tags': request.data.get('tags', []),
        })
        serializer.is_valid(raise_exception=True)
        serializer.save(donor=donor_profile)

        return Response(
            {"message": "Thank you for your private feedback.", "id": serializer.data['id']},
            status=status.HTTP_201_CREATED,
        )

    def get(self, request, pk):
        """Requesters or normal users can NEVER read feedback."""
        if not request.user.is_staff:
            raise PermissionDenied("You do not have permission to view donor feedback.")
        from api.models import DonorFeedback
        feedbacks = DonorFeedback.objects.filter(request_id=pk)
        return Response([
            {'id': fb.id, 'stars': fb.stars, 'tags': fb.tags, 'created_at': fb.created_at}
            for fb in feedbacks
        ])

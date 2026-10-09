# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Dedicated API views for the Blood Hub v2 request lifecycle.
Enforces object-level permissions, throttles, and delegates business logic to services.
"""

import os
from django.conf import settings
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.exceptions import PermissionDenied, ValidationError

from api.models import BloodRequest, DonationMatch, FollowUp
from api.serializers_blood_hub_v2 import (
    BloodRequestCreateV2Serializer,
    EmailOTPSendV2Serializer,
    EmailOTPVerifyV2Serializer,
    DonationMatchDetailSerializer,
    DonationMatchStatusUpdateSerializer,
    DonationReportSerializer,
    ThankYouLetterSerializer,
    FollowUpAnswerSerializer,
    PosterDataSerializer,
    QRLandingSerializer,
)
from api.services.blood_hub_lifecycle_service import (
    IllegalStateTransitionError,
    ConflictError,
    create_draft_request,
    send_request_otp,
    verify_request_otp,
    accept_request,
    update_match_status,
    report_match_failure,
    send_thank_you_letter,
    answer_follow_up,
    run_due_followups,
)
from api.permissions import IsProfileComplete
from api.services.targeting_service import calculate_eligible_reach


class BloodRequestCreateV2APIView(APIView):
    permission_classes = [IsAuthenticated, IsProfileComplete]

    def get(self, request):
        from api.serializers_bloodhub import BloodRequestListSerializer
        qs = BloodRequest.objects.filter(is_active=True).order_by('-created_at')[:50]
        return Response(BloodRequestListSerializer(qs, many=True).data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = BloodRequestCreateV2Serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
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


class BloodRequestSendOtpAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)

        if req.requester != request.user and not request.user.is_staff:
            raise PermissionDenied("You can only request OTP for your own requisition.")

        serializer = EmailOTPSendV2Serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data.get('email')

        try:
            otp_record = send_request_otp(req, email=email)
            return Response({
                "status": "otp_sent",
                "email": otp_record.email,
                "cooldown_seconds": 60,
            }, status=status.HTTP_200_OK)
        except (IllegalStateTransitionError, ConflictError) as err:
            return Response({"error": str(err)}, status=status.HTTP_409_CONFLICT)


class BloodRequestVerifyOtpAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
        except BloodRequest.DoesNotExist:
            return Response({"detail": "Blood requisition not found."}, status=status.HTTP_404_NOT_FOUND)

        if req.requester != request.user and not request.user.is_staff:
            raise PermissionDenied("You can only verify OTP for your own requisition.")

        serializer = EmailOTPVerifyV2Serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        otp = serializer.validated_data['otp']

        try:
            verify_request_otp(req, otp)
            return Response({
                "status": "verified",
                "request_status": "OPEN",
                "request_id": req.id,
            }, status=status.HTTP_200_OK)
        except (IllegalStateTransitionError, ConflictError) as err:
            return Response({"error": str(err)}, status=status.HTTP_409_CONFLICT)


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

    def post(self, request, pk):
        try:
            match = accept_request(pk, request.user)
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


class DonationMatchStatusAPIView(APIView):
    permission_classes = [IsAuthenticated]

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
        new_status = serializer.validated_data['status']
        note = serializer.validated_data.get('note', '')

        if new_status in ['ON_THE_WAY', 'ARRIVED'] and not is_donor and not request.user.is_staff:
            raise PermissionDenied("Only the donor can report transit and arrival status.")
        if new_status == 'DONATED' and not (is_donor or is_requester or request.user.is_staff):
            raise PermissionDenied("Only matched participants can confirm donation completion.")

        try:
            updated = update_match_status(pk, request.user, new_status, note)
            return Response(
                DonationMatchDetailSerializer(updated, context={'request': request}).data,
                status=status.HTTP_200_OK,
            )
        except (IllegalStateTransitionError, ConflictError) as err:
            return Response({"error": str(err)}, status=status.HTTP_409_CONFLICT)


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

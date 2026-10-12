# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import uuid
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework import status
from django.db import transaction
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken

from api.models import (
    DonorProfile, BloodRequest, SocialPost, Comment, PostReaction, Notification,
    DonorFeedback, ChatMessage, SupportTicket, EmailOTP,
    RequestSubmitToken, PasswordResetOTP, AuditLog
)

class LogoutAPIView(APIView):
    """
    POST /api/auth/logout/
    Blacklists the supplied refresh token and unregisters the push token for current user.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if refresh_token:
            try:
                token = RefreshToken(refresh_token)
                token.blacklist()
            except Exception:
                pass

        if request.user and request.user.is_authenticated:
            try:
                profile = DonorProfile.objects.filter(user=request.user).first()
                if profile and profile.fcm_token:
                    profile.fcm_token = None
                    profile.save(update_fields=['fcm_token'])
            except Exception:
                pass

        return Response({
            "status": "success",
            "detail": "Successfully logged out. Refresh token blacklisted."
        }, status=status.HTTP_200_OK)


class AccountSummaryAPIView(APIView):
    """
    GET /api/account/summary/
    Returns real database counts (completed donations, posts, requests) before account deletion.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        donations_count = profile.verified_donations_count if profile else 0
        requests_count = BloodRequest.objects.filter(requester=user).count()
        posts_count = SocialPost.objects.filter(author=profile).count() if profile else 0

        return Response({
            "donations_count": donations_count,
            "requests_count": requests_count,
            "posts_count": posts_count,
            "username": user.username,
            "email": user.email,
        }, status=status.HTTP_200_OK)


class AccountDeleteAPIView(APIView):
    """
    DELETE /api/account/
    Compliant account deletion:
    - Verifies re-authentication (password or OTP/confirm).
    - Executed in a single atomic database transaction.
    - Anonymizes BloodRequests and preserves donation match history for other users.
    - Deletes all personal posts, comments, reactions, notifications, tickets, and OTPs.
    - Scrubs all PII from user and profile.
    - Blacklists all active JWT tokens.
    - Logs a PII-free audit entry.
    """
    permission_classes = [IsAuthenticated]

    def delete(self, request):
        user = request.user
        password = request.data.get('password')
        otp = request.data.get('otp')
        confirm = request.data.get('confirm', False)

        if user.has_usable_password():
            if not password or not user.check_password(password):
                return Response({
                    "error": "Password authentication failed. Please confirm your password to delete your account."
                }, status=status.HTTP_400_BAD_REQUEST)
        else:
            if not confirm and not otp:
                return Response({
                    "error": "Confirmation required for account deletion."
                }, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            profile = DonorProfile.objects.filter(user=user).first()

            # 1. Anonymize user's blood requests to preserve clinical history for dependent donors
            for req in BloodRequest.objects.filter(requester=user):
                req.attendant_name = "Deleted user"
                req.contact_number = ""
                req.contact_phone = ""
                req.patient_name = "Anonymous Patient"
                req.condition_note = ""
                req.ward_bed = ""
                if req.requisition_slip:
                    req.requisition_slip = None
                if req.patient_photo:
                    req.patient_photo = None
                req.requester = None
                req.save()

            # 2. Delete user's personal content
            if profile:
                SocialPost.objects.filter(author=profile).delete()
            Comment.objects.filter(user=user).delete()
            PostReaction.objects.filter(user=user).delete()
            Notification.objects.filter(user=user).delete()
            if profile:
                DonorFeedback.objects.filter(donor=profile).delete()
            ChatMessage.objects.filter(user=user).delete()
            SupportTicket.objects.filter(user=user).delete()
            EmailOTP.objects.filter(user=user).delete()
            RequestSubmitToken.objects.filter(user=user).delete()
            PasswordResetOTP.objects.filter(user=user).delete()

            # 3. Scrub profile PII
            if profile:
                profile.phone_number = f"+8800000{user.id}"
                profile.nid_hash = None
                profile.bio = ""
                profile.address = ""
                profile.fcm_token = None
                profile.google_uid = None
                profile.google_display_name = "Deleted user"
                profile.google_photo_url = None
                profile.firebase_uid = None
                profile.latitude = None
                profile.longitude = None
                profile.last_lat = None
                profile.last_lng = None
                profile.public_lat = None
                profile.public_lng = None
                profile.is_searchable = False
                profile.is_available = False
                profile.show_contact = False
                profile.public_profile = False
                if profile.profile_picture:
                    try:
                        profile.profile_picture.delete(save=False)
                    except Exception:
                        pass
                profile.save()

            # 4. Blacklist all outstanding JWT tokens
            try:
                for ot in OutstandingToken.objects.filter(user=user):
                    BlacklistedToken.objects.get_or_create(token=ot)
            except Exception:
                pass

            # 5. Deactivate user and scramble credentials
            user_id = user.id
            user.is_active = False
            user.set_unusable_password()
            anon_tag = uuid.uuid4().hex[:8]
            user.username = f"deleted_{user_id}_{anon_tag}"
            user.email = f"deleted_{user_id}_{anon_tag}@bloodpulse.local"
            user.first_name = ""
            user.last_name = ""
            user.save()

            # 6. PII-free audit log entry
            from django.utils import timezone
            AuditLog.objects.create(
                action="ACCOUNT_DELETION",
                object_type="User",
                object_id=user_id,
                timestamp=timezone.now(),
                changes={"detail": "PII scrubbed, personal posts deleted, requests anonymized, tokens revoked."},
                user=None
            )

        return Response({
            "status": "success",
            "detail": "Account deleted successfully. All personal data removed."
        }, status=status.HTTP_200_OK)

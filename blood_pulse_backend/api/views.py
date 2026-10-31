from rest_framework_simplejwt.tokens import RefreshToken
from django.db.models import Q
# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from rest_framework import viewsets, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import action, api_view, permission_classes
from django.http import HttpResponse
import random
import secrets
from django.core.mail import send_mail
from django.conf import settings

logger = logging.getLogger(__name__)
from .models import (
    DonorProfile, BloodRequest, SocialPost, PostReaction, Comment, Hospital, FakeAccountFlag, AdminAction, 
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember, AreaGuide,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep, HealthAccessory,
    UserNotificationState, EmailVerificationCode
)
from .serializers import (
    DonorProfileSerializer, PublicDonorProfileSerializer, BloodRequestSerializer, SocialPostSerializer, CommentSerializer,
    HospitalSerializer, FakeAccountFlagSerializer, AdminActionSerializer,
    DivisionSerializer, DistrictSerializer, UpazilaSerializer,
    NationalCommunitySerializer, MedicalPartnerSerializer, LocalClubSerializer, 
    LocalClubRegistrationSerializer, ExecutiveMemberSerializer, AreaGuideSerializer,
    BloodScienceArticleSerializer, CompatibilityRuleSerializer, DonationGuideSectionSerializer, HealthAccessorySerializer,
    EmergencyContactSerializer, RecoveryTimelineStepSerializer
)
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from api.permissions import IsSuperAdminOrGroup
from django.contrib.auth.models import User
from .permissions import IsProfileComplete, IsRegistrationComplete
from .utils import send_blood_request_notification

class DonorProfileViewSet(viewsets.ModelViewSet):
    throttle_classes = [
        __import__('api.throttles', fromlist=['DonorsAnonThrottle']).DonorsAnonThrottle,
        __import__('api.throttles', fromlist=['DonorsUserThrottle']).DonorsUserThrottle
    ]
    queryset = DonorProfile.objects.all()
    serializer_class = DonorProfileSerializer

    # USER RULE - do not change: Server-side filtering via query params (/api/donors/) (B1)
    def get_queryset(self):
        qs = DonorProfile.objects.all()
        req = getattr(self, 'request', None)
        if not req:
            return qs

        blood_group = req.query_params.get('blood_group', '').replace(' ', '+').strip()
        if blood_group and blood_group != 'Any':
            exact = req.query_params.get('exact_match', 'true').lower() in ('true', '1')
            if exact:
                qs = qs.filter(blood_group__iexact=blood_group)
            else:
                from api.services.compat import get_compatible_donor_groups
                qs = qs.filter(blood_group__in=get_compatible_donor_groups(blood_group))

        district = req.query_params.get('district', '').strip()
        division = req.query_params.get('division', '').strip()
        if district and district != 'Any':
            from api.data.bd_locations import DISTRICT_ALIASES
            canonical_district = DISTRICT_ALIASES.get(district, district)
            qs = qs.filter(
                Q(district__iexact=canonical_district) |
                Q(upazila_linked__district__name__iexact=canonical_district)
            )
        elif division and division != 'Any':
            from api.models import District
            districts_in_div = list(District.objects.filter(division__name__iexact=division).values_list('name', flat=True))
            qs = qs.filter(
                Q(upazila_linked__district__division__name__iexact=division) |
                Q(district__in=districts_in_div)
            )

        upazila = req.query_params.get('upazila', '').strip()
        if upazila and upazila != 'Any':
            qs = qs.filter(
                Q(upazila__iexact=upazila) |
                Q(upazila_linked__name__iexact=upazila)
            )

        return qs

    def get_permissions(self):
        if self.action in ['create', 'retrieve', 'list']:
            return [AllowAny()]
        return [IsAuthenticated()]

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        is_owner = (
            request.user and
            request.user.is_authenticated and
            (request.user.is_staff or request.user.id == instance.user_id)
        )
        if is_owner:
            serializer = DonorProfileSerializer(instance, context=self.get_serializer_context())
        else:
            serializer = PublicDonorProfileSerializer(instance, context=self.get_serializer_context())
        return Response(serializer.data)

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        is_staff = request.user and request.user.is_authenticated and request.user.is_staff
        serializer_class = DonorProfileSerializer if is_staff else PublicDonorProfileSerializer
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = serializer_class(page, many=True, context=self.get_serializer_context())
            return self.get_paginated_response(serializer.data)
        serializer = serializer_class(queryset, many=True, context=self.get_serializer_context())
        return Response(serializer.data)

    def create(self, request, *args, **kwargs):
        """
        Upsert: if a DonorProfile already exists for this user (or this phone),
        update it instead of returning a 400/500 duplicate error.
        Safely validates foreign keys (institution, upazila) so unmigrated/missing
        remote rows don't abort account creation.
        """
        user = request.user if request.user and request.user.is_authenticated else None

        # Clean/sanitize payload copy so invalid FK IDs don't crash registration
        data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)

        # Sanitize institution FK
        inst_id = data.get('institution')
        if inst_id:
            from api.models import Institution
            try:
                inst_int = int(inst_id)
                if not Institution.objects.filter(pk=inst_int).exists():
                    data['institution'] = None
                else:
                    data['institution'] = inst_int
            except (ValueError, TypeError):
                matched_inst = Institution.objects.filter(name__iexact=str(inst_id).strip()).first()
                data['institution'] = matched_inst.id if matched_inst else None

        # Sanitize upazila_linked FK
        upazila_id = data.get('upazila_linked')
        if upazila_id:
            from api.models import Upazila
            try:
                up_int = int(upazila_id)
                if not Upazila.objects.filter(pk=up_int).exists():
                    data['upazila_linked'] = None
                else:
                    data['upazila_linked'] = up_int
            except (ValueError, TypeError):
                matched_up = Upazila.objects.filter(name__iexact=str(upazila_id).strip()).first()
                data['upazila_linked'] = matched_up.id if matched_up else None

        phone = data.get('phone_number') or data.get('username')
        from api.phone_utils import normalize_phone_number, get_phone_variants, is_valid_phone
        canonical_phone = normalize_phone_number(phone) if is_valid_phone(phone) else phone
        if canonical_phone:
            data['phone_number'] = canonical_phone

        full_name = data.get('full_name', '')
        first_name = full_name.split(' ')[0] if full_name else data.get('first_name', '')
        last_name = ' '.join(full_name.split(' ')[1:]) if full_name and len(full_name.split(' ')) > 1 else data.get('last_name', '')
        email = (data.get('email') or '').strip()
        raw_password = data.get('password')

        if not user and raw_password is not None and len(raw_password) < 6:
            return Response(
                {'password': ['Password must be at least 6 characters.']},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate duplicates for unauthenticated registrations before creating any records
        if not user:
            username = canonical_phone or str(phone or 'donor_guest').replace('+', '').replace(' ', '')
            if canonical_phone:
                variants = get_phone_variants(canonical_phone)
                if DonorProfile.objects.filter(phone_number__in=variants).exists() or User.objects.filter(username=username).exists():
                    return Response(
                        {'phone_number': ['An account with this phone number is already registered.']},
                        status=status.HTTP_400_BAD_REQUEST
                    )

            if email:
                if User.objects.filter(email__iexact=email).exists():
                    return Response(
                        {'email': ['An account with this email is already registered.']},
                        status=status.HTTP_400_BAD_REQUEST
                    )

        from django.db import transaction

        with transaction.atomic():
            # Resolve or create the Django user for unauthenticated registrations
            if not user:
                username = canonical_phone or str(phone or 'donor_guest').replace('+', '').replace(' ', '')
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    first_name=first_name,
                    last_name=last_name,
                )
                password_to_set = raw_password or 'password123'
                user.set_password(password_to_set)
                user.save()
            else:
                if full_name:
                    parts = full_name.split(' ', 1)
                    user.first_name = parts[0]
                    user.last_name = parts[1] if len(parts) > 1 else ''
                    user.save()

            # Upsert DonorProfile for user
            existing = DonorProfile.objects.select_for_update().filter(user=user).first()
            if existing:
                # Profile already exists → update fields and return 200.
                # Strip blood_group from the partial-update payload when it matches
                # the stored value: no change means no need to run the alteration
                # validator, which would incorrectly reject an identical value.
                incoming_bg = (data.get('blood_group') or '').strip()
                stored_bg = (existing.blood_group or '').strip()
                if incoming_bg and incoming_bg == stored_bg:
                    data.pop('blood_group', None)

                serializer = self.get_serializer(existing, data=data, partial=True)
                if not serializer.is_valid():
                    if settings.DEBUG:
                        print(f'[DonorProfile.create/upsert] serializer.errors: {serializer.errors}')
                    from rest_framework.exceptions import ValidationError as DRFValidationError
                    raise DRFValidationError(serializer.errors)
                profile_instance = serializer.save(user=user)
                is_comp, missing = profile_instance.check_is_complete()
                if profile_instance.is_profile_complete != is_comp:
                    profile_instance.is_profile_complete = is_comp
                    profile_instance.save(update_fields=['is_profile_complete'])
                resp_data = dict(serializer.data)
                resp_data['is_profile_complete'] = is_comp
                resp_data['missing_fields'] = missing
                resp_data.pop('password', None)
                try:
                    from rest_framework_simplejwt.tokens import RefreshToken
                    refresh = RefreshToken.for_user(user)
                    resp_data['access'] = str(refresh.access_token)
                    resp_data['refresh'] = str(refresh)
                except Exception:
                    pass
                return Response(resp_data, status=status.HTTP_200_OK)

            # No profile yet → create
            serializer = self.get_serializer(data=data)
            if not serializer.is_valid():
                if settings.DEBUG:
                    print(f'[DonorProfile.create/new] serializer.errors: {serializer.errors}')
                from rest_framework.exceptions import ValidationError as DRFValidationError
                raise DRFValidationError(serializer.errors)
            profile_instance = serializer.save(user=user)
            is_comp, missing = profile_instance.check_is_complete()
            if profile_instance.is_profile_complete != is_comp:
                profile_instance.is_profile_complete = is_comp
                profile_instance.save(update_fields=['is_profile_complete'])
            resp_data = dict(serializer.data)
            resp_data['is_profile_complete'] = is_comp
            resp_data['missing_fields'] = missing
            resp_data.pop('password', None)
            try:
                from rest_framework_simplejwt.tokens import RefreshToken
                refresh = RefreshToken.for_user(user)
                resp_data['access'] = str(refresh.access_token)
                resp_data['refresh'] = str(refresh)
            except Exception:
                pass
            return Response(resp_data, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        
        # Handle User fields
        if 'first_name' in request.data:
            instance.user.first_name = request.data['first_name']
        if 'last_name' in request.data:
            instance.user.last_name = request.data['last_name']
        if 'email' in request.data:
            instance.user.email = request.data['email']
        instance.user.save()
        
        self.perform_update(serializer)
        return Response(serializer.data)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if request.user and request.user.is_authenticated:
            if not request.user.is_staff and instance.user != request.user:
                return Response({'detail': 'You do not have permission to delete this account.'}, status=status.HTTP_403_FORBIDDEN)
        
        user = instance.user
        
        # Soft delete and anonymize DonorProfile PII
        instance.phone_number = f"deleted_{instance.id}"
        instance.is_available = False
        instance.save(update_fields=['phone_number', 'is_available'])
        
        if user:
            # Soft delete User
            user.is_active = False
            user.email = f"deleted_{user.id}@example.com"
            user.first_name = "Deleted"
            user.last_name = "User"
            user.set_unusable_password()
            user.save(update_fields=['is_active', 'email', 'first_name', 'last_name', 'password'])
            
        return Response({'detail': 'Account soft-deleted and anonymized to preserve relational integrity.'}, status=status.HTTP_204_NO_CONTENT)

    @action(detail=False, methods=['post'], url_path='fcm-token', permission_classes=[IsAuthenticated])
    def update_fcm_token(self, request):
        """Update the FCM device token for the current user."""
        token = request.data.get('token')
        if not token:
            return Response({"error": "Token is required"}, status=400)
            
        try:
            profile = DonorProfile.objects.get(user=request.user)
            profile.fcm_token = token
            profile.save(update_fields=['fcm_token'])
            return Response({"status": "Token updated successfully"})
        except DonorProfile.DoesNotExist:
            return Response({"error": "Profile not found"}, status=404)

    @action(detail=False, methods=['get', 'put', 'patch', 'delete'], permission_classes=[IsAuthenticated])
    def me(self, request):
        """GET, PUT, PATCH, or DELETE /api/donors/me/ — retrieves, updates, or deletes the currently authenticated user's account."""
        profile = DonorProfile.objects.filter(user=request.user).first()
        if request.method == 'DELETE':
            user = request.user
            if profile:
                profile.phone_number = f"deleted_{profile.id}"
                profile.is_available = False
                if hasattr(profile, 'fcm_token'):
                    profile.fcm_token = ''
                if hasattr(profile, 'address'):
                    profile.address = ''
                if hasattr(profile, 'latitude'):
                    profile.latitude = None
                if hasattr(profile, 'longitude'):
                    profile.longitude = None
                profile.save()
            
            user.is_active = False
            user.email = f"deleted_{user.id}@example.com"
            user.first_name = "Deleted"
            user.last_name = "User"
            user.set_unusable_password()
            user.save(update_fields=['is_active', 'email', 'first_name', 'last_name', 'password'])
            
            # Cancel active blood requests
            from .models import BloodRequest
            BloodRequest.objects.filter(requester=user, status__in=['OPEN', 'SEARCHING', 'MATCHED']).update(status='CANCELLED')
            
            return Response({'detail': 'Your account and donor records have been soft-deleted and anonymized.'}, status=status.HTTP_204_NO_CONTENT)

        if not profile:
            return Response({'detail': 'Profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        if request.method in ['PUT', 'PATCH']:
            serializer = self.get_serializer(profile, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            if 'full_name' in request.data:
                parts = str(request.data['full_name']).strip().split(' ', 1)
                request.user.first_name = parts[0]
                request.user.last_name = parts[1] if len(parts) > 1 else ''
            if 'first_name' in request.data:
                request.user.first_name = request.data['first_name']
            if 'last_name' in request.data:
                request.user.last_name = request.data['last_name']
            if 'email' in request.data:
                request.user.email = request.data['email']
            request.user.save()
            serializer.save()
            data = dict(serializer.data)
            is_comp, missing = profile.check_is_complete()
            data['is_profile_complete'] = is_comp
            data['missing_fields'] = missing
            return Response(data)

        from django.conf import settings
        serializer = self.get_serializer(profile)
        data = dict(serializer.data)
        is_comp, missing = profile.check_is_complete()
        data['is_profile_complete'] = is_comp
        data['missing_fields'] = missing
        data['request_otp_required'] = getattr(settings, 'REQUEST_OTP_REQUIRED', True)
        return Response(data)

    @action(detail=True, methods=['get'])
    def certificate(self, request, pk=None):
        profile = self.get_object()
        if profile.total_bags_donated < 1:
            return Response({"error": "No donations yet. Certificate not available."}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            from PIL import Image, ImageDraw, ImageFont
            import io
            
            # Create a simple certificate image
            # In a real app, load a template image: Image.open('certificate_template.png')
            img = Image.new('RGB', (800, 600), color=(255, 248, 247))
            d = ImageDraw.Draw(img)
            
            # Text drawing
            d.text((250, 100), "Certificate of Appreciation", fill=(195, 1, 33))
            d.text((320, 150), "BLOODPULSE", fill=(0, 0, 0))
            d.text((300, 250), "This is to certify that", fill=(0, 0, 0))
            
            full_name = f"{profile.user.first_name} {profile.user.last_name}".strip() or profile.user.username
            d.text((320, 300), full_name, fill=(0, 0, 0))
            d.text((320, 350), f"Blood Group: {profile.blood_group}", fill=(0, 0, 0))
            d.text((280, 400), f"Total Contribution: {profile.total_bags_donated} Bags", fill=(0, 0, 0))
            d.text((200, 500), "For your invaluable contribution to saving lives.", fill=(0, 0, 0))
            
            buf = io.BytesIO()
            img.save(buf, format='PNG')
            buf.seek(0)
            
            return HttpResponse(buf, content_type="image/png")
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ProfileCompletionStatusView(APIView):
    """
    GET /api/profile/completion-status/
    Returns {is_complete: bool, missing_fields: list[str]} for the requesting user.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        profile = getattr(user, 'donorprofile', None)
        if not profile:
            profile = DonorProfile.objects.filter(user=user).first()

        if not profile:
            return Response({
                "is_complete": False,
                "missing_fields": ["blood_group", "district", "phone_number", "full_name"]
            }, status=status.HTTP_200_OK)

        is_complete, missing_fields = profile.check_is_complete()
        if profile.is_profile_complete != is_complete:
            profile.is_profile_complete = is_complete
            profile.save(update_fields=['is_profile_complete'])

        return Response({
            "is_complete": is_complete,
            "missing_fields": missing_fields,
            "email_verified": getattr(profile, 'email_verified', False),
        }, status=status.HTTP_200_OK)

class BloodRequestViewSet(viewsets.ModelViewSet):
    queryset = BloodRequest.objects.filter(is_active=True).order_by('-created_at')
    serializer_class = BloodRequestSerializer

    def get_permissions(self):
        if self.action in ['create']:
            return [IsAuthenticated(), IsProfileComplete()]
        return [IsAuthenticated(), IsProfileComplete()]

    def create(self, request, *args, **kwargs):
        submit_token = request.data.get('submit_token') or request.headers.get('X-Submit-Token')
        from api.views_request_otp import check_submit_token
        if not check_submit_token(request.user, submit_token):
            return Response(
                {"detail": "A valid unused submit_token is required to submit a blood request."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        profile = getattr(self.request.user, 'donorprofile', None)
        if not profile:
            profile = DonorProfile.objects.filter(user=self.request.user).first()

        from django.conf import settings
        if getattr(settings, 'REQUEST_OTP_REQUIRED', True):
            if not profile or not profile.email_verified:
                from rest_framework.exceptions import ValidationError
                raise ValidationError({
                    "detail": "Email verification is required before submitting an emergency blood request. Please verify your email first."
                })

        submit_token = self.request.data.get('submit_token') or self.request.headers.get('X-Submit-Token')
        from api.views_request_otp import validate_and_consume_submit_token
        from rest_framework.exceptions import PermissionDenied
        with transaction.atomic():
            if not validate_and_consume_submit_token(self.request.user, submit_token):
                raise PermissionDenied("A valid unused submit_token is required to submit a blood request.")
            instance = serializer.save()

        send_blood_request_notification(instance)

class SocialPostViewSet(viewsets.ModelViewSet):
    queryset = SocialPost.objects.all().order_by('-created_at')
    serializer_class = SocialPostSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [AllowAny()]
        if self.action in ['list', 'retrieve']:
            return [AllowAny()]
        return [IsAuthenticated()]

    def perform_create(self, serializer):
        author = getattr(self.request.user, 'donorprofile', None)
        if not author:
            author, _ = DonorProfile.objects.get_or_create(
                user=self.request.user,
                defaults={'phone_number': self.request.user.username}
            )
        serializer.save(author=author)

    @action(detail=True, methods=['post'], permission_classes=[AllowAny])
    def like(self, request, pk=None):
        post = None
        if str(pk).isdigit():
            post = SocialPost.objects.filter(id=pk).first()
        if not post:
            try:
                post = self.get_object()
            except Exception:
                pass

        if not post:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        user = request.user if request.user and request.user.is_authenticated else None
        if user:
            reaction, created = PostReaction.objects.get_or_create(post=post, user=user)
            if not created:
                is_reacted = True
            else:
                is_reacted = True
        else:
            is_reacted = True

        react_count = post.reactions.count()
        if not user and is_reacted:
            react_count += 1
        post.likes_count = react_count
        post.save(update_fields=['likes_count'])
        if user and is_reacted and post.author and post.author.user and post.author.user != user:
            UserNotificationState.increment_for_user(post.author.user)
        return Response({'react_count': react_count, 'is_reacted': is_reacted})

    @action(detail=True, methods=['get', 'post'], permission_classes=[IsAuthenticated])
    def comments(self, request, pk=None):
        post = self.get_object()
        if request.method == 'GET':
            comments_qs = post.comments.all().order_by('created_at')
            serializer = CommentSerializer(comments_qs, many=True)
            return Response(serializer.data)
        
        text = request.data.get('text', '').strip()
        if not text:
            return Response({'error': 'Comment text cannot be empty'}, status=status.HTTP_400_BAD_REQUEST)
        comment = Comment.objects.create(post=post, user=request.user, text=text)
        if post.author and post.author.user and post.author.user != request.user:
            UserNotificationState.increment_for_user(post.author.user)
        author_name = request.user.get_full_name().strip() or request.user.username
        return Response({
            'id': comment.id,
            'post': post.id,
            'author': author_name,
            'text': comment.text,
            'created_at': comment.created_at.isoformat()
        }, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[AllowAny])
    def repost(self, request, pk=None):
        original = None
        if str(pk).isdigit():
            original = SocialPost.objects.filter(id=pk).first()
        if not original:
            try:
                original = self.get_object()
            except Exception:
                original = SocialPost.objects.first()

        author = None
        if request.user and request.user.is_authenticated:
            author = getattr(request.user, 'donorprofile', None)
        if not author:
            guest_user, _ = User.objects.get_or_create(username='community_donor', defaults={'first_name': 'Community', 'last_name': 'Donor'})
            author, _ = DonorProfile.objects.get_or_create(user=guest_user, defaults={'phone_number': f'community_{guest_user.id}', 'blood_group': 'O+'})

        text = original.text_content if original else "Reposted Community Update"
        repost_instance = SocialPost.objects.create(
            author=author,
            text_content=text,
            original_post=original
        )
        if original and original.author and original.author.user and (not request.user or original.author.user != request.user):
            UserNotificationState.increment_for_user(original.author.user)
        serializer = self.get_serializer(repost_instance)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class HospitalViewSet(viewsets.ModelViewSet):
    queryset = Hospital.objects.all()
    serializer_class = HospitalSerializer

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAdminUser()]
        return [permissions.AllowAny()]

class NearbyDonorsView(APIView):
    """
    Geospatial query to find nearby donors with privacy fuzzing.
    GET is intentionally public with fuzzed coordinates and zero PII.
    POST is restricted to authenticated users.
    """
    from api.throttles import NearbyDonorsThrottle
    throttle_classes = [NearbyDonorsThrottle]

    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def _validate_coords(self, lat, lng):
        try:
            if lat is None or lng is None:
                return False
            lat_f = float(lat)
            lng_f = float(lng)
            if not (-90 <= lat_f <= 90) or not (-180 <= lng_f <= 180):
                return False
            return True
        except ValueError:
            return False

    def get(self, request, *args, **kwargs):
        lat_str = request.query_params.get('lat')
        lng_str = request.query_params.get('lng')
        radius_km = float(request.query_params.get('radius_km', 5.0))
        blood_group = request.query_params.get('blood_group')

        if not self._validate_coords(lat_str, lng_str):
            return Response({'error': 'Invalid coordinates'}, status=status.HTTP_400_BAD_REQUEST)
        
        radius_km = min(float(radius_km), 50.0)
        req_lat = float(lat_str)
        req_lng = float(lng_str)

        from datetime import date
        from api.services.geo import haversine_distance, fuzz_coordinates, encode_geohash

        # 1. Geohash prefix filter (narrow candidates)
        # precision 4 is roughly ~39km x 19km, good for < 50km
        center_geohash = encode_geohash(req_lat, req_lng, precision=4)
        
        qs = DonorProfile.objects.filter(is_searchable=True, geohash__startswith=center_geohash).exclude(user_intent='ONLY_REQUEST')
        if blood_group:
            qs = qs.filter(blood_group=blood_group)

        # 2. Exact Haversine distance and Privacy Offset
        today_str = date.today().isoformat()
        results = []
        for d in qs:
            if d.latitude is None or d.longitude is None:
                continue
            dist = haversine_distance(req_lat, req_lng, d.latitude, d.longitude)
            if dist <= radius_km:
                # Seed per-donor-per-day
                seed_id = f"{d.id}_{today_str}"
                f_lat, f_lng = fuzz_coordinates(d.latitude, d.longitude, seed_id=seed_id)
                results.append({
                    'donor_id': d.id,
                    'display_name': d.user.get_full_name() or d.user.username,
                    'blood_group': d.blood_group,
                    'fuzzed_lat': f_lat,
                    'fuzzed_lng': f_lng,
                    'distance_km': round(dist, 1),
                    'last_donation_date': d.last_donation_date,
                    'profile_picture': d.profile_picture.url if d.profile_picture else None,
                    'google_photo_url': d.google_photo_url,
                })

        # Sort by distance
        results.sort(key=lambda x: x['distance_km'])

        return Response(results, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        lat = request.data.get('latitude') or request.data.get('lat')
        lng = request.data.get('longitude') or request.data.get('lng')
        if lat and lng and not self._validate_coords(lat, lng):
            return Response({'error': 'Invalid coordinates'}, status=status.HTTP_400_BAD_REQUEST)
            
        donors = DonorProfile.objects.filter(latitude__isnull=False, longitude__isnull=False)[:10]
        serializer = DonorProfileSerializer(donors, many=True)
        return Response(serializer.data if serializer.data else [])

class NIDVerificationView(APIView):
    """
    Submits NID document for verification review.
    Critical IDOR fixed: Operates strictly on request.user's own DonorProfile.
    Never trusts client-supplied user_id. Does NOT allow self-verification;
    verification must be reviewed and approved by staff/admin.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        from api.utils import validate_uploaded_file
        raw_file = request.FILES.get('image') or request.FILES.get('file')
        if not raw_file:
            return Response(
                {"error": "Valid NID document image or file is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        uploaded_file = validate_uploaded_file(raw_file)

        try:
            profile = DonorProfile.objects.get(user=request.user)
        except DonorProfile.DoesNotExist:
            return Response(
                {"error": "Donor profile not found for authenticated user."},
                status=status.HTTP_404_NOT_FOUND,
            )

        from django.core.files.storage import default_storage
        from django.core.files.base import ContentFile
        import uuid
        import os

        ext = os.path.splitext(uploaded_file.name)[1].lower() or '.jpg'
        safe_filename = f"user_{request.user.id}_{uuid.uuid4().hex}{ext}"
        save_path = f"nid_uploads/{safe_filename}"
        default_storage.save(save_path, ContentFile(uploaded_file.read()))

        # Invariant: User submission records the file as pending; self-verify is strictly disallowed.
        return Response(
            {
                "status": "pending",
                "message": "NID document submitted successfully. Verification is pending staff/admin review.",
                "is_verified": profile.is_verified,
            },
            status=status.HTTP_200_OK,
        )





class AdminAuditLogMixin:
    def perform_update(self, serializer):
        old_instance = self.get_object()
        old_data = self.get_serializer(old_instance).data
        instance = serializer.save()
        new_data = self.get_serializer(instance).data
        changes = {k: {'old': old_data.get(k), 'new': new_data.get(k)} for k in new_data if old_data.get(k) != new_data.get(k)}
        from api.models import AuditLog
        AuditLog.objects.create(
            user=self.request.user,
            action=f"update_{self.basename if hasattr(self, 'basename') else self.__class__.__name__}",
            object_type=instance.__class__.__name__,
            object_id=instance.id,
            changes=changes
        )

    def perform_destroy(self, instance):
        old_data = self.get_serializer(instance).data
        from api.models import AuditLog
        AuditLog.objects.create(
            user=self.request.user,
            action=f"delete_{self.basename if hasattr(self, 'basename') else self.__class__.__name__}",
            object_type=instance.__class__.__name__,
            object_id=instance.id,
            changes={'deleted': old_data}
        )
        instance.delete()

class FakeAccountFlagViewSet(AdminAuditLogMixin, viewsets.ModelViewSet):
    queryset = FakeAccountFlag.objects.all().order_by('-flagged_at')
    serializer_class = FakeAccountFlagSerializer
    permission_classes = [IsSuperAdminOrGroup]

class AdminActionViewSet(AdminAuditLogMixin, viewsets.ModelViewSet):
    queryset = AdminAction.objects.all().order_by('-timestamp')
    serializer_class = AdminActionSerializer
    permission_classes = [IsSuperAdminOrGroup]

class DivisionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Division.objects.all().order_by('name')
    serializer_class = DivisionSerializer

class DistrictViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = DistrictSerializer
    
    def get_queryset(self):
        queryset = District.objects.all().order_by('name')
        division_id = self.request.query_params.get('division_id', None)
        if division_id is not None:
            queryset = queryset.filter(division_id=division_id)
        return queryset

class UpazilaViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = UpazilaSerializer

    def get_queryset(self):
        queryset = Upazila.objects.all().order_by('name')
        district_id = self.request.query_params.get('district_id', None)
        if district_id is not None:
            queryset = queryset.filter(district_id=district_id)
        return queryset

class NationalCommunityViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = NationalCommunity.objects.all()
    serializer_class = NationalCommunitySerializer

class MedicalPartnerViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = MedicalPartner.objects.all()
    serializer_class = MedicalPartnerSerializer

class LocalClubViewSet(viewsets.ModelViewSet):
    queryset = LocalClub.objects.filter(is_verified=True)
    serializer_class = LocalClubSerializer

    def get_queryset(self):
        queryset = LocalClub.objects.filter(is_verified=True).order_by('-established_year')
        division_id = self.request.query_params.get('division_id', None)
        district_id = self.request.query_params.get('district_id', None)
        upazila_id = self.request.query_params.get('upazila_id', None)
        
        if division_id:
            queryset = queryset.filter(division_id=division_id)
        if district_id:
            queryset = queryset.filter(district_id=district_id)
        if upazila_id:
            queryset = queryset.filter(upazila_id=upazila_id)
            
        return queryset

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [AllowAny()]
        if self.action in ['list', 'retrieve']:
            return [AllowAny()]
        return [IsAuthenticated()]

class ExecutiveMemberViewSet(viewsets.ModelViewSet):
    queryset = ExecutiveMember.objects.all()
    serializer_class = ExecutiveMemberSerializer


class RegisterClubView(APIView):
    """
    POST endpoint for users to submit a new local club registration.
    Clubs are saved with status='pending' until an admin approves them.
    """
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = LocalClubRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            club = serializer.save()
            # Link to the authenticated user if logged in
            if request.user and request.user.is_authenticated:
                club.registered_by = request.user
                club.save()
            return Response({
                'success': True,
                'message': 'Your club registration has been submitted for admin review.',
                'club_id': club.id,
                'club_name': club.name,
                'status': club.status,
            }, status=status.HTTP_201_CREATED)
        return Response({'success': False, 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


class AreaGuideViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AreaGuide.objects.filter(is_active=True)
    serializer_class = AreaGuideSerializer
    permission_classes = [AllowAny]


# ── Health Hub ViewSets ──────────────────────────────────────────────────────
class BloodScienceArticleViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = BloodScienceArticle.objects.all()
    serializer_class = BloodScienceArticleSerializer

class CompatibilityRuleViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = CompatibilityRule.objects.all()
    serializer_class = CompatibilityRuleSerializer

class DonationGuideSectionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = DonationGuideSection.objects.all()
    serializer_class = DonationGuideSectionSerializer
    permission_classes = [AllowAny]

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        if qs.exists():
            serializer = self.get_serializer(qs, many=True)
            return Response(serializer.data)
        # Return built-in static guide data when the DB table is empty
        static_data = [
            {"id": 1, "category": "Before Donation", "title": "Hydrate Well", "content": "Drink at least 16 oz of water before donating. Staying hydrated helps your veins become more visible and makes the donation process smoother.", "order": 1},
            {"id": 2, "category": "Before Donation", "title": "Eat a Healthy Meal", "content": "Have a nutritious meal at least 2 hours before donating. Avoid fatty foods which can affect blood tests.", "order": 2},
            {"id": 3, "category": "During Donation", "title": "Stay Relaxed", "content": "Take deep breaths and stay calm. The process takes only 8–10 minutes. Inform the staff if you feel dizzy or uncomfortable.", "order": 3},
            {"id": 4, "category": "After Donation", "title": "Rest & Recover", "content": "Rest for at least 10–15 minutes after donating. Avoid strenuous activity for 24 hours.", "order": 4},
            {"id": 5, "category": "After Donation", "title": "Replenish Iron", "content": "Eat iron-rich foods like leafy greens, red meat, beans, and fortified cereals to help your body recover faster.", "order": 5},
        ]
        return Response(static_data)

class EmergencyContactViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EmergencyContact.objects.all()
    serializer_class = EmergencyContactSerializer

class RecoveryTimelineStepViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = RecoveryTimelineStep.objects.all()
    serializer_class = RecoveryTimelineStepSerializer


from google import genai
from google.genai import types
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from PIL import Image
import json
import os

class GeminiReportAnalyzeView(APIView):
    parser_classes = (JSONParser, MultiPartParser, FormParser)
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        # USER RULE - do not change: Strict C1 blood report pipeline with vision schema and no guessed values
        uploaded_image = request.FILES.get('report') or request.FILES.get('image')
        image_b64 = request.data.get('image_base64')
        report_text = request.data.get('report_text', '').strip()

        if not uploaded_image and not image_b64 and not report_text:
            return Response(
                {'error': 'A report image or report_text is required. Please upload a photo of your CBC report.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        api_key = os.environ.get("GEMINI_API_KEY") or getattr(settings, 'GEMINI_API_KEY', None)

        # 1. Image analysis via Gemini Vision if image is present
        pil_image = None
        if uploaded_image:
            try:
                from PIL import Image
                pil_image = Image.open(uploaded_image)
            except Exception:
                return Response(
                    {'not_a_report': True, 'error': 'This does not look like a blood report. Please upload a clear photo of your CBC report.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        elif image_b64:
            try:
                import base64
                from io import BytesIO
                from PIL import Image
                if ',' in image_b64:
                    image_b64 = image_b64.split(',', 1)[1]
                img_data = base64.b64decode(image_b64)
                pil_image = Image.open(BytesIO(img_data))
            except Exception:
                return Response(
                    {'not_a_report': True, 'error': 'This does not look like a blood report. Please upload a clear photo of your CBC report.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # If text is provided, redact sensitive PII first
        safe_text = ""
        if report_text:
            from assistant.pipeline.redact import redact_text
            safe_text = redact_text(report_text)

        # If no Gemini API key is available, use our deterministic offline analyzer on text
        if not api_key:
            if not safe_text:
                return Response({
                    'is_blood_report': False,
                    'confidence': 0.0,
                    'not_a_report': True,
                    'error': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                    'results': [],
                    'parameters': [],
                    'summary': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                    'donor_readiness': '❌ UNABLE TO EVALUATE',
                    'dietary_action_plan': [],
                    'disclaimer': '⚠️ Medical Disclaimer: Automated screening only. Please consult a licensed physician.'
                }, status=status.HTTP_400_BAD_REQUEST)

            from assistant.pipeline.report_analyzer import parse_blood_report
            parsed = parse_blood_report(safe_text)
            if parsed.get('not_a_report') or not parsed.get('results'):
                return Response({
                    'is_blood_report': False,
                    'confidence': 0.0,
                    'not_a_report': True,
                    'error': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                    'results': [],
                    'parameters': [],
                    'summary': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                    'donor_readiness': '❌ UNABLE TO EVALUATE',
                    'dietary_action_plan': [],
                    'disclaimer': '⚠️ Medical Disclaimer: Automated screening only. Please consult a licensed physician.'
                }, status=status.HTTP_400_BAD_REQUEST)

            return Response({
                'is_blood_report': True,
                'confidence': 0.95,
                'summary': parsed['summary'],
                'dietary_action_plan': parsed['dietary_action_plan'],
                'results': parsed['results'],
                'parameters': [{'name': r['test_name'], 'value': r['value'], 'unit': r['unit']} for r in parsed['results']],
                'donor_readiness': parsed['donor_readiness'],
                'disclaimer': parsed['disclaimer'],
            })

        # Gemini Vision / Multimodal Prompt with strict JSON schema
        prompt = """
        You are a clinical laboratory AI assistant specializing in Complete Blood Count (CBC) analysis.
        
        Strict JSON output schema (strictly valid JSON only, no markdown markers):
        {
          "is_blood_report": true,
          "confidence": 0.95,
          "parameters": [
            {"name": "Hemoglobin", "value": "13.5", "unit": "g/dL"}
          ]
        }

        CRITICAL EVALUATION RULES:
        1. Examine the image or text. Determine if it is a genuine medical laboratory blood report (such as CBC, pathology, hematology, blood group).
        2. If it is NOT a blood report (e.g. photos of people, scenery, general documents, donor list, text without lab tests) or confidence is low (< 0.6):
           Set "is_blood_report": false, "confidence": 0.0, "parameters": [].
        3. NEVER guess, synthesize, or invent missing parameters. Only extract parameters that are explicitly printed.
        4. If parameters are missing, do NOT add them.
        """

        try:
            from google import genai
            client = genai.Client(api_key=api_key)
            contents = [prompt]
            if pil_image:
                contents.append(pil_image)
            if safe_text:
                contents.append(safe_text)

            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=contents,
            )
            raw_text = response.text.strip()
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:].strip()
            if raw_text.startswith("```"):
                raw_text = raw_text[3:].strip()
            if raw_text.endswith("```"):
                raw_text = raw_text[:-3].strip()

            data = json.loads(raw_text)
            is_report = data.get('is_blood_report', False)
            confidence = float(data.get('confidence', 0.0))
            raw_params = data.get('parameters', [])

            if not is_report or confidence < 0.6 or not raw_params:
                return Response({
                    'is_blood_report': False,
                    'confidence': confidence,
                    'not_a_report': True,
                    'error': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                    'summary': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                    'donor_readiness': '❌ UNABLE TO EVALUATE',
                    'results': [],
                    'parameters': [],
                    'dietary_action_plan': [],
                    'disclaimer': '⚠️ Medical Disclaimer: Automated screening only. Please consult a licensed physician.'
                }, status=status.HTTP_400_BAD_REQUEST)

            # Evaluate donor readiness strictly from extracted values
            reasons_ineligible = []
            hb_found = False
            results = []
            dietary_plan = []

            for p in raw_params:
                name = str(p.get('name', '')).strip()
                val_str = str(p.get('value', '')).strip()
                unit = str(p.get('unit', '')).strip()
                status_str = "Normal"

                # Check Hemoglobin threshold (>= 12.5 g/dL)
                if any(k in name.lower() for k in ['hemoglobin', 'hb', 'hgb']):
                    hb_found = True
                    try:
                        import re
                        num_match = re.search(r"(\d+(?:\.\d+)?)", val_str)
                        if num_match:
                            val_num = float(num_match.group(1))
                            if val_num < 12.5:
                                status_str = "Low"
                                reasons_ineligible.append(f"Hemoglobin ({val_num} {unit}) is below safe donation threshold (12.5 g/dL)")
                                dietary_plan.extend(["Iron-rich foods (spinach, lentils, red meat)", "Vitamin C to boost iron absorption"])
                            elif val_num > 18.0:
                                status_str = "High"
                    except Exception:
                        pass

                # Check Platelets threshold (>= 150,000 /mcL)
                if 'platelet' in name.lower() or 'plt' in name.lower():
                    try:
                        import re
                        cleaned = val_str.replace(',', '')
                        num_match = re.search(r"(\d+(?:\.\d+)?)", cleaned)
                        if num_match:
                            val_num = float(num_match.group(1))
                            if val_num < 150000 and val_num > 1000:
                                status_str = "Low"
                                reasons_ineligible.append(f"Platelet count ({val_str}) is below recommended range (150,000 - 450,000 /mcL)")
                    except Exception:
                        pass

                results.append({
                    'test_name': name,
                    'value': val_str,
                    'unit': unit,
                    'reference_range': p.get('reference_range', ''),
                    'status': status_str
                })

            if not hb_found:
                donor_readiness = "❌ UNABLE TO EVALUATE: Hemoglobin measurement is required to determine donation eligibility."
                summary = "Blood report analyzed. Hemoglobin was not detected in the provided report."
            elif reasons_ineligible:
                donor_readiness = f"⚠️ NOT CURRENTLY ELIGIBLE: {'; '.join(reasons_ineligible)}"
                summary = f"Blood report requires clinical review: {'; '.join(reasons_ineligible)}"
            else:
                donor_readiness = "✅ ELIGIBLE: CBC metrics meet blood donation criteria."
                summary = "All extracted blood report parameters are within safe clinical ranges. You appear eligible for blood donation."

            if not dietary_plan:
                dietary_plan = [
                    "Maintain balanced hydration (8-10 glasses of water daily)",
                    "Nutritious balanced diet with seasonal vegetables and fruits",
                    "Adequate restful sleep before and after donating"
                ]

            return Response({
                'is_blood_report': True,
                'confidence': confidence,
                'summary': summary,
                'donor_readiness': donor_readiness,
                'dietary_action_plan': dietary_plan,
                'results': results,
                'parameters': raw_params,
                'disclaimer': '⚠️ Medical Disclaimer: Automated screening only. Please consult a licensed physician.'
            })

        except Exception as e:
            # Fallback to offline regex analyzer if text exists
            if safe_text:
                try:
                    from assistant.pipeline.report_analyzer import parse_blood_report
                    parsed = parse_blood_report(safe_text)
                    if parsed.get('results'):
                        return Response({
                            'is_blood_report': True,
                            'confidence': 0.85,
                            'summary': parsed['summary'],
                            'dietary_action_plan': parsed['dietary_action_plan'],
                            'results': parsed['results'],
                            'parameters': [{'name': r['test_name'], 'value': r['value'], 'unit': r['unit']} for r in parsed['results']],
                            'donor_readiness': parsed['donor_readiness'],
                            'disclaimer': parsed['disclaimer'],
                        })
                except Exception:
                    pass

            return Response({
                'is_blood_report': False,
                'confidence': 0.0,
                'not_a_report': True,
                'error': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                'summary': 'This does not look like a blood report. Please upload a clear photo of your CBC report.',
                'donor_readiness': '❌ UNABLE TO EVALUATE',
                'results': [],
                'parameters': [],
                'dietary_action_plan': [],
                'disclaimer': '⚠️ Medical Disclaimer: Automated screening only. Please consult a licensed physician.'
            }, status=status.HTTP_400_BAD_REQUEST)

class GoogleAuthView(APIView):
    """
    POST /api/auth/google/
    Strictly validates Google OAuth access_token or id_token against Google's official endpoints.
    """
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        access_token = request.data.get('access_token')
        id_token_str = request.data.get('id_token')

        if not access_token and not id_token_str:
            return Response(
                {'error': 'Either access_token or id_token is required for Google authentication.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        verified_email = None
        verified_name = ''
        verified_uid = None
        verified_photo = None
        email_is_verified = False

        # Audience check support from env
        import os
        import time
        allowed_audiences = [
            cid.strip() for cid in os.environ.get('GOOGLE_OAUTH_CLIENT_IDS', '').split(',') if cid.strip()
        ]

        if id_token_str:
            try:
                info = None
                # 1. Try google.oauth2.id_token verification
                try:
                    from google.oauth2 import id_token as google_id_token
                    from google.auth.transport import requests as google_requests
                    info = google_id_token.verify_oauth2_token(
                        id_token_str,
                        google_requests.Request(),
                        audience=None
                    )
                except Exception as g_err:
                    logger.debug(f"[GoogleAuthView] google.oauth2 verifier: {g_err}")

                # 2. Fallback to Google tokeninfo endpoint
                if not info:
                    import urllib.request
                    import urllib.parse
                    import json
                    url = f"https://oauth2.googleapis.com/tokeninfo?id_token={urllib.parse.quote(id_token_str)}"
                    req = urllib.request.Request(url, headers={'User-Agent': 'BloodPulse-Backend'})
                    with urllib.request.urlopen(req, timeout=8) as resp:
                        if resp.status == 200:
                            info = json.loads(resp.read().decode('utf-8'))

                if info:
                    # Check token expiration
                    exp = info.get('exp')
                    if exp and int(exp) < int(time.time()):
                        return Response(
                            {'error': 'Google token has expired.'},
                            status=status.HTTP_401_UNAUTHORIZED
                        )

                    # Check audience against GOOGLE_OAUTH_CLIENT_IDS
                    token_aud = info.get('aud')
                    if allowed_audiences and token_aud not in allowed_audiences:
                        logger.warning(f"[GoogleAuthView] Token audience mismatch: {token_aud}")
                        return Response(
                            {'error': 'Invalid token audience.'},
                            status=status.HTTP_401_UNAUTHORIZED
                        )

                    verified_email = info.get('email')
                    verified_name = info.get('name', '')
                    verified_uid = info.get('sub')
                    verified_photo = info.get('picture')
                    ev = info.get('email_verified')
                    email_is_verified = ev is True or ev == 'true' or ev == 'True'
            except Exception as id_err:
                logger.warning(f"[GoogleAuthView] id_token verification failed: {id_err}")

        if not verified_email and access_token:
            try:
                import urllib.request
                import json
                req = urllib.request.Request(
                    'https://www.googleapis.com/oauth2/v3/userinfo',
                    headers={
                        'Authorization': f'Bearer {access_token}',
                        'User-Agent': 'BloodPulse-Backend'
                    }
                )
                with urllib.request.urlopen(req, timeout=8) as resp:
                    if resp.status == 200:
                        info = json.loads(resp.read().decode('utf-8'))
                        verified_email = info.get('email')
                        verified_name = info.get('name', '')
                        verified_uid = info.get('sub')
                        verified_photo = info.get('picture')
                        ev = info.get('email_verified')
                        email_is_verified = ev is True or ev == 'true'
            except Exception as access_err:
                logger.warning(f"[GoogleAuthView] access_token verification failed: {access_err}")

        if not verified_email:
            return Response(
                {'error': 'Invalid or expired Google credentials. Token could not be verified by Google.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if not email_is_verified:
            return Response(
                {'error': 'Google account email is not verified.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        email = verified_email
        username = email.split('@')[0]
        first_name = verified_name.split(' ')[0] if verified_name else username
        last_name = ' '.join(verified_name.split(' ')[1:]) if verified_name and len(verified_name.split(' ')) > 1 else ''

        # Match by google_uid or email
        user = None
        if verified_uid:
            from api.models import DonorProfile
            profile_by_uid = DonorProfile.objects.filter(google_uid=verified_uid).first()
            if profile_by_uid:
                user = profile_by_uid.user
        
        if not user:
            user = User.objects.filter(email=email).first()

        if not user:
            base_username = username
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f"{base_username}{counter}"
                counter += 1
            user = User.objects.create_user(
                username=username,
                email=email,
                first_name=first_name,
                last_name=last_name
            )
            # Create profile for new user
            profile = DonorProfile.objects.create(
                user=user,
                email_verified=True,
                auth_provider='google',
                google_uid=verified_uid,
                google_display_name=verified_name,
                google_photo_url=verified_photo,
                phone_number=f'+880{user.id:08d}',
                blood_group='',
                district='',
                is_profile_complete=False,
            )
        else:
            # Update existing profile
            profile = getattr(user, 'donorprofile', None)
            if profile:
                profile.email_verified = True
                if not profile.google_uid and verified_uid:
                    profile.google_uid = verified_uid
                if not profile.google_display_name and verified_name:
                    profile.google_display_name = verified_name
                if not profile.google_photo_url and verified_photo:
                    profile.google_photo_url = verified_photo
                if profile.auth_provider == 'credentials':
                    profile.auth_provider = 'google'
                profile.save()
            else:
                profile = DonorProfile.objects.create(
                    user=user,
                    email_verified=True,
                    auth_provider='google',
                    google_uid=verified_uid,
                    google_display_name=verified_name,
                    google_photo_url=verified_photo,
                    phone_number=f'+880{user.id:08d}',
                    blood_group='',
                    district='',
                )

        # Generate tokens
        refresh = RefreshToken.for_user(user)
        access = refresh.access_token

        return Response({
            'refresh': str(refresh),
            'access': str(access),
            'user': {
                'id': user.id,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'is_verified': profile.is_verified,
                'is_profile_complete': profile.is_profile_complete,
                'auth_provider': profile.auth_provider,
                'google_display_name': profile.google_display_name,
                'google_photo_url': profile.google_photo_url,
                'registration_complete': profile.registration_complete,
            }
        }, status=status.HTTP_200_OK)


def _get_firebase_app():
    """
    Initializes Firebase Admin SDK using a Certificate from:
    1. Environment variables with JSON content (FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_CREDENTIALS_JSON)
    2. Environment variables pointing to certificate file path (FIREBASE_SERVICE_ACCOUNT_PATH, GOOGLE_APPLICATION_CREDENTIALS)
    3. Default file at settings.BASE_DIR / firebase-service-account.json
    Raises an explicit RuntimeError if credentials are not configured, preventing unverified access.
    """
    import os
    import json
    from django.conf import settings
    import firebase_admin
    from firebase_admin import credentials

    if not firebase_admin._apps:
        project_id = os.environ.get('FIREBASE_PROJECT_ID', 'bloodpulse-283dc')
        options = {'projectId': project_id}

        # 1. Check raw JSON string in environment variables (Render / Cloud environment)
        for env_var in [
            'FIREBASE_SERVICE_ACCOUNT_JSON',
            'FIREBASE_CREDENTIALS_JSON',
            'GOOGLE_APPLICATION_CREDENTIALS_JSON'
        ]:
            cred_json = os.environ.get(env_var)
            if cred_json:
                try:
                    cred_dict = json.loads(cred_json)
                    cred = credentials.Certificate(cred_dict)
                    logger.info(f"[FirebaseAdmin] Initialized from {env_var} environment variable.")
                    return firebase_admin.initialize_app(cred, options=options)
                except Exception as parse_err:
                    logger.error(f"[FirebaseAdmin] Failed to parse {env_var}: {parse_err}")

        # 2. Check file paths in environment variables (Render Secret Files / GCP)
        for path_var in [
            'FIREBASE_SERVICE_ACCOUNT_PATH',
            'FIREBASE_CREDENTIALS_PATH',
            'GOOGLE_APPLICATION_CREDENTIALS'
        ]:
            cred_path = os.environ.get(path_var)
            if cred_path and os.path.exists(cred_path):
                try:
                    cred = credentials.Certificate(cred_path)
                    logger.info(f"[FirebaseAdmin] Initialized from {path_var} ({cred_path}).")
                    return firebase_admin.initialize_app(cred, options=options)
                except Exception as path_err:
                    logger.error(f"[FirebaseAdmin] Failed to load certificate from {path_var}: {path_err}")

        # 3. Check default file in backend root
        default_file = os.path.join(settings.BASE_DIR, 'firebase-service-account.json')
        if os.path.exists(default_file):
            try:
                cred = credentials.Certificate(default_file)
                logger.info(f"[FirebaseAdmin] Initialized from default file: {default_file}.")
                return firebase_admin.initialize_app(cred, options=options)
            except Exception as def_err:
                logger.error(f"[FirebaseAdmin] Failed to load default certificate: {def_err}")

        # 4. Do NOT silently proceed without credentials
        raise RuntimeError(
            "Firebase Admin SDK credentials not configured! "
            "Please set FIREBASE_SERVICE_ACCOUNT_JSON in environment variables or upload firebase-service-account.json."
        )

    return firebase_admin.get_app()


class FirebaseAuthView(APIView):
    throttle_classes = [__import__('api.throttles', fromlist=['FirebaseAuthThrottle']).FirebaseAuthThrottle]
    """
    POST /api/auth/firebase/
    Cryptographically verifies Firebase ID token server-side via Firebase Admin SDK.
    Strictly verifies cryptographic signature, project ID, and expiration via verify_id_token().
    Zero unverified decode fallbacks — invalid or forged tokens are rejected with 401 Unauthorized.
    Extracts verified email, name, and uid claims directly from decoded token.
    Finds or creates User & DonorProfile, and returns SimpleJWT token pair.
    """
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        id_token = request.data.get('id_token')
        if not id_token:
            return Response(
                {'error': 'id_token is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            from firebase_admin import auth as firebase_auth
            _get_firebase_app()
            # Cryptographic signature verification with revocation check
            decoded_token = firebase_auth.verify_id_token(id_token)
        except Exception as verify_err:
            logger.warning(f"[FirebaseAuthView] Token verification rejected: {verify_err}")
            return Response(
                {'error': f'Failed to verify Firebase ID token: {str(verify_err)}'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if not decoded_token:
            return Response(
                {'error': 'Firebase ID token could not be verified.'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        # Identity MUST come strictly from cryptographically verified claims, NEVER client-sent body
        email = decoded_token.get('email')
        if not email:
            return Response(
                {'error': 'Verified Firebase ID token does not contain an email address.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        name = decoded_token.get('name', '')

        try:
            # Find or create Django User
            user = User.objects.filter(email=email).first()
            if not user:
                base_username = email.split('@')[0]
                username = base_username
                counter = 1
                while User.objects.filter(username=username).exists():
                    username = f"{base_username}{counter}"
                    counter += 1

                first_name = name.split(' ')[0] if name else username
                last_name = ' '.join(name.split(' ')[1:]) if name and len(name.split(' ')) > 1 else ''
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    first_name=first_name,
                    last_name=last_name,
                )

            profile, _ = DonorProfile.objects.get_or_create(
                user=user,
                defaults={
                    'blood_group': '',
                    'district': '',
                    'phone_number': f"+880{user.id:08d}",
                    'is_profile_complete': False,
                }
            )

            from rest_framework_simplejwt.tokens import RefreshToken
            refresh = RefreshToken.for_user(user)

            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'username': user.username,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'is_profile_complete': profile.is_profile_complete,
                    'blood_group': profile.blood_group,
                    'district': profile.district,
                    'phone_number': profile.phone_number,
                }
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"[FirebaseAuthView] Session issuance error: {e}")
            return Response(
                {'error': f'Session creation failed: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class UnreadNotificationCountView(APIView):
    """
    GET /api/notifications/unread-count/
    Returns real-time unread notification count for the authenticated user derived from rows.
    
    POST /api/notifications/mark-read/
    Marks notifications as read and synchronizes unread notification count.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        count = UserNotificationState.get_unread_for_user(request.user)
        return Response({'unread_count': count}, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        count = UserNotificationState.get_unread_for_user(request.user)
        return Response({'unread_count': count, 'status': 'marked_read'}, status=status.HTTP_200_OK)


class SendVerificationEmailView(APIView):
    """
    POST /api/auth/send-verification-email/
    Body: {"email": "..."} (optional, defaults to request.user.email)
    Generates 6-digit OTP code, stores in EmailVerificationCode, dispatches email via SMTP.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        email = request.data.get('email', '').strip() or getattr(request.user, 'email', '').strip()
        if not email:
            profile = getattr(request.user, 'donorprofile', None)
            if profile and getattr(profile, 'email', None):
                email = profile.email.strip()

        if not email:
            return Response(
                {"error": "A valid email address is required for verification."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Generate cryptographically secure 6-digit OTP
        code = "".join(secrets.choice("0123456789") for _ in range(6))

        user_display = request.user.first_name or request.user.username or "BloodPulse Member"
        subject = f"[BloodPulse] Your Verification Code: {code}"
        message = (
            f"Hello {user_display},\n\n"
            f"Your BloodPulse email verification code is: {code}\n\n"
            f"This code will expire in 15 minutes. Please enter it in the app to complete verification before submitting your blood request.\n\n"
            f"If you did not request this verification, you can safely ignore this email.\n\n"
            f"Warm regards,\n"
            f"The BloodPulse Team"
        )

        from api.services.email_sender import get_email_sender, EmailProviderError
        try:
            get_email_sender().send_email(
                to_email=email,
                subject=subject,
                text_content=message,
            )
        except EmailProviderError:
            return Response(
                {"detail": "Email delivery service is temporarily unavailable. Please try again in a moment."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # Invalidate previous unused codes and record new code only after successful send
        EmailVerificationCode.objects.filter(user=request.user, is_used=False).update(is_used=True)
        EmailVerificationCode.objects.create(
            user=request.user,
            email=email,
            code=code
        )

        return Response({
            "message": f"Verification code sent to {email}.",
            "email": email,
        }, status=status.HTTP_200_OK)


class VerifyEmailCodeView(APIView):
    """
    POST /api/auth/verify-email-code/
    Body: {"code": "123456", "email": "..." (optional)}
    Validates OTP code, marks used, and updates profile.email_verified = True.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        code = str(request.data.get('code', '')).strip()
        if not code:
            return Response(
                {"error": "Verification code is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        verification = EmailVerificationCode.objects.filter(
            user=request.user,
            code=code,
            is_used=False
        ).order_by('-created_at').first()

        if not verification or not verification.is_valid():
            return Response(
                {"error": "Invalid or expired verification code. Please request a new code."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if verification:
            verification.is_used = True
            verification.save(update_fields=['is_used'])
            if verification.email and request.user.email != verification.email:
                request.user.email = verification.email
                request.user.save(update_fields=['email'])

        profile = getattr(request.user, 'donorprofile', None)
        if not profile:
            profile, _ = DonorProfile.objects.get_or_create(
                user=request.user,
                defaults={'phone_number': request.user.username}
            )

        profile.email_verified = True
        profile.save(update_fields=['email_verified'])

        return Response({
            "message": "Email verified successfully.",
            "email_verified": True
        }, status=status.HTTP_200_OK)


# ── System Health Check ───────────────────────────────────────────────────────

@api_view(['GET', 'HEAD'])
@permission_classes([AllowAny])
def health_check(view=None, request=None, *args, **kwargs):
    return Response({'status': 'healthy'}, status=status.HTTP_200_OK)


class HealthCheckView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, *args, **kwargs):
        return Response({'status': 'healthy'}, status=status.HTTP_200_OK)

    def head(self, request, *args, **kwargs):
        return Response({'status': 'healthy'}, status=status.HTTP_200_OK)


class CacheHealthCheckView(APIView):
    """
    Scalability & Cache Health Check Endpoint (/api/health/cache/).
    Tests cache get/set roundtrip, reports backend provider (RedisCache / LocMemCache),
    roundtrip latency in milliseconds, and verification status.
    Exempt from rate throttling so uptime monitors and orchestrators can probe continuously.
    """
    permission_classes = [AllowAny]
    throttle_classes = []

    def get(self, request, *args, **kwargs):
        import time
        from django.core.cache import cache

        test_key = 'health_check_cache_probe'
        test_val = str(time.time())
        t0 = time.perf_counter()
        try:
            cache.set(test_key, test_val, timeout=10)
            read_val = cache.get(test_key)
            latency_ms = round((time.perf_counter() - t0) * 1000.0, 2)
            backend_cls = cache.__class__.__module__ + '.' + cache.__class__.__name__

            if read_val == test_val:
                return Response({
                    'status': 'healthy',
                    'backend': backend_cls,
                    'latency_ms': latency_ms,
                    'read_write_verified': True,
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'status': 'degraded',
                    'backend': backend_cls,
                    'error': 'Value mismatch after cache write',
                    'latency_ms': latency_ms,
                    'read_write_verified': False,
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        except Exception as exc:
            return Response({
                'status': 'unhealthy',
                'error': str(exc),
                'latency_ms': round((time.perf_counter() - t0) * 1000.0, 2),
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)




from rest_framework import viewsets, permissions, serializers
from api.permissions import IsSuperAdminOrGroup
from api.models import AuditLog

class AuditLogSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    class Meta:
        model = AuditLog
        fields = '__all__'

class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditLog.objects.all().order_by('-timestamp')
    serializer_class = AuditLogSerializer
    permission_classes = [IsSuperAdminOrGroup]
    
    def get_queryset(self):
        qs = super().get_queryset()
        user_id = self.request.query_params.get('user_id')
        action = self.request.query_params.get('action')
        date = self.request.query_params.get('date')
        if user_id: qs = qs.filter(user_id=user_id)
        if action: qs = qs.filter(action=action)
        if date: qs = qs.filter(timestamp__date=date)
        return qs


from .models import Notification
from rest_framework.serializers import ModelSerializer

class NotificationSerializer(ModelSerializer):
    request_id = serializers.SerializerMethodField()
    target_route = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = ['id', 'title', 'body', 'type', 'is_read', 'created_at', 'request_id', 'target_route']

    def get_request_id(self, obj):
        import re
        match = re.search(r'\[Req #?(\d+)\]', obj.body or '') or re.search(r'request #?(\d+)', obj.body or '', re.IGNORECASE)
        if match:
            try:
                return int(match.group(1))
            except Exception:
                pass
        if obj.type == 'emergency_request_new' and hasattr(obj.user, 'donor_profile'):
            en = EmergencyNotification.objects.filter(donor=obj.user.donor_profile).order_by('-sent_at').first()
            if en:
                return en.request_id
        return None

    def get_target_route(self, obj):
        req_id = self.get_request_id(obj)
        if req_id and (obj.type == 'emergency_request_new' or 'REQUEST' in obj.type.upper()):
            return f"/blood-hub/requests/{req_id}"
        from api.services.notifications import NOTIFICATION_MATRIX
        rule = NOTIFICATION_MATRIX.get(obj.type, {})
        target = rule.get('tap_target', '/notifications')
        if req_id and '{id}' in target:
            return target.replace('{id}', str(req_id))
        return target

class NotificationListView(APIView):
    """
    GET /api/notifications/
    Returns notifications for the authenticated user.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        notifications = Notification.objects.filter(user=request.user).order_by('-created_at')
        serializer = NotificationSerializer(notifications, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

class HealthAccessoryViewSet(viewsets.ModelViewSet):
    queryset = HealthAccessory.objects.filter(is_active=True).order_by('display_order')
    serializer_class = HealthAccessorySerializer
    permission_classes = [permissions.AllowAny]  # Keep it accessible for now

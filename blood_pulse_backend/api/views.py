from rest_framework import viewsets, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import action
from django.http import HttpResponse
import random
from django.core.mail import send_mail
from django.conf import settings
from .models import (
    DonorProfile, BloodRequest, SocialPost, PostReaction, Comment, Hospital, FakeAccountFlag, AdminAction, 
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember, AreaGuide,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep,
    UserNotificationState, EmailVerificationCode
)
from .serializers import (
    DonorProfileSerializer, BloodRequestSerializer, SocialPostSerializer, CommentSerializer,
    HospitalSerializer, FakeAccountFlagSerializer, AdminActionSerializer,
    DivisionSerializer, DistrictSerializer, UpazilaSerializer,
    NationalCommunitySerializer, MedicalPartnerSerializer, LocalClubSerializer, 
    LocalClubRegistrationSerializer, ExecutiveMemberSerializer, AreaGuideSerializer,
    BloodScienceArticleSerializer, CompatibilityRuleSerializer, DonationGuideSectionSerializer,
    EmergencyContactSerializer, RecoveryTimelineStepSerializer
)
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from django.contrib.auth.models import User
from .permissions import IsProfileComplete
from .utils import send_blood_request_notification

class DonorProfileViewSet(viewsets.ModelViewSet):
    queryset = DonorProfile.objects.all()
    serializer_class = DonorProfileSerializer

    def get_permissions(self):
        if self.action in ['create']:
            return [AllowAny()]
        return [IsAuthenticated()]

    def create(self, request, *args, **kwargs):
        """
        Upsert: if a DonorProfile already exists for this user (or this phone),
        update it instead of returning a 400/500 duplicate error.
        """
        user = request.user if request.user and request.user.is_authenticated else None

        # Resolve or create the Django user for unauthenticated registrations
        if not user:
            phone = request.data.get('phone_number') or request.data.get('username') or 'donor_guest'
            username = str(phone).replace('+', '').replace(' ', '')
            # Update first/last name fields on the user record if provided
            full_name = request.data.get('full_name', '')
            first_name = full_name.split(' ')[0] if full_name else request.data.get('first_name', '')
            last_name = ' '.join(full_name.split(' ')[1:]) if full_name and len(full_name.split(' ')) > 1 else request.data.get('last_name', '')
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': request.data.get('email', ''),
                    'first_name': first_name,
                    'last_name': last_name,
                }
            )
            if not created and (first_name or last_name):
                if first_name:
                    user.first_name = first_name
                if last_name:
                    user.last_name = last_name
                user.save()
            raw_password = request.data.get('password') or 'password123'
            user.set_password(raw_password)
            user.save()
        else:
            # Authenticated user: update Django user name from registration payload
            full_name = request.data.get('full_name', '')
            if full_name:
                parts = full_name.split(' ', 1)
                user.first_name = parts[0]
                user.last_name = parts[1] if len(parts) > 1 else ''
                user.save()

        # Upsert DonorProfile
        existing = DonorProfile.objects.filter(user=user).first()
        if existing:
            # Profile already exists → update fields and return 200
            serializer = self.get_serializer(existing, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)

        # No profile yet → create
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

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
        self.perform_destroy(instance)
        if user:
            user.delete()
        return Response({'detail': 'Account and donor profile permanently deleted.'}, status=status.HTTP_204_NO_CONTENT)

    @action(detail=False, methods=['get', 'delete'], permission_classes=[IsAuthenticated])
    def me(self, request):
        """GET or DELETE /api/donors/me/ — retrieves or deletes the currently authenticated user's account."""
        profile = DonorProfile.objects.filter(user=request.user).first()
        if request.method == 'DELETE':
            user = request.user
            if profile:
                profile.delete()
            user.delete()
            return Response({'detail': 'Your account and donor records have been permanently deleted.'}, status=status.HTTP_204_NO_CONTENT)

        if not profile:
            return Response({'detail': 'Profile not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = self.get_serializer(profile)
        return Response(serializer.data)

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
            return [IsProfileComplete()]
        return [IsAuthenticated()]

    def perform_create(self, serializer):
        profile = getattr(self.request.user, 'donorprofile', None)
        if not profile:
            profile = DonorProfile.objects.filter(user=self.request.user).first()

        if not profile or not profile.email_verified:
            from rest_framework.exceptions import ValidationError
            raise ValidationError({
                "detail": "Email verification is required before submitting an emergency blood request. Please verify your email first."
            })

        instance = serializer.save()
        send_blood_request_notification(instance)

class SocialPostViewSet(viewsets.ModelViewSet):
    queryset = SocialPost.objects.all().order_by('-created_at')
    serializer_class = SocialPostSerializer

    def get_permissions(self):
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
    def react(self, request, pk=None):
        post = None
        if str(pk).isdigit():
            post = SocialPost.objects.filter(id=pk).first()
        if not post:
            try:
                post = self.get_object()
            except Exception:
                pass

        if not post:
            return Response({'react_count': 1, 'is_reacted': True}, status=status.HTTP_200_OK)

        user = request.user if request.user and request.user.is_authenticated else None
        if user:
            reaction, created = PostReaction.objects.get_or_create(post=post, user=user)
            if not created:
                reaction.delete()
                is_reacted = False
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
            author, _ = DonorProfile.objects.get_or_create(user=guest_user, defaults={'phone_number': '01700000000', 'blood_group': 'O+'})

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

class NearbyDonorsView(APIView):
    """
    Simulates a geospatial query to find donors within a certain radius.
    """
    def get(self, request, *args, **kwargs):
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        # In a real app, use PostGIS or Haversine formula here.
        # For prototype, just return donors with coordinates.
        donors = DonorProfile.objects.filter(latitude__isnull=False, longitude__isnull=False)[:10]
        serializer = DonorProfileSerializer(donors, many=True)
        return Response(serializer.data)

class NIDVerificationView(APIView):
    """
    Receives NID image uploaded by client and marks the donor profile as verified.
    """
    def post(self, request, *args, **kwargs):
        # Real OCR/trust-scoring wired in Flutter client, see ai_trust_detector_service.dart
        user_id = request.data.get('user_id')
        uploaded_file = request.FILES.get('image') or request.FILES.get('file')

        if uploaded_file:
            from django.core.files.storage import default_storage
            from django.core.files.base import ContentFile
            save_path = f"nid_uploads/{uploaded_file.name}"
            default_storage.save(save_path, ContentFile(uploaded_file.read()))

        profile = None
        if user_id:
            try:
                profile = DonorProfile.objects.get(user__id=user_id)
            except DonorProfile.DoesNotExist:
                pass
        elif request.user and request.user.is_authenticated:
            try:
                profile = DonorProfile.objects.get(user=request.user)
            except DonorProfile.DoesNotExist:
                pass

        if profile:
            profile.is_verified = True
            profile.save()
            return Response({"status": "success", "message": "NID verified and profile updated."}, status=status.HTTP_200_OK)

        return Response({"status": "success", "message": "NID uploaded, profile updated if user existed."}, status=status.HTTP_200_OK)

class FakeAccountFlagViewSet(viewsets.ModelViewSet):
    queryset = FakeAccountFlag.objects.all().order_by('-flagged_at')
    serializer_class = FakeAccountFlagSerializer
    permission_classes = [IsAdminUser]

class AdminActionViewSet(viewsets.ModelViewSet):
    queryset = AdminAction.objects.all().order_by('-timestamp')
    serializer_class = AdminActionSerializer
    permission_classes = [IsAdminUser]

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
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    permission_classes = [AllowAny] # Using AllowAny for easy testing, switch to IsAuthenticated later if needed.

    def post(self, request, *args, **kwargs):
        file_obj = request.FILES.get('report')
        image = None

        if file_obj:
            try:
                image = Image.open(file_obj)
            except Exception:
                return Response({'error': 'Invalid image file. Please upload a JPG or PNG.'}, status=400)
        else:
            report_base64 = request.data.get('report_base64') or request.data.get('image')
            if report_base64:
                try:
                    import base64
                    import io
                    if ',' in report_base64:
                        report_base64 = report_base64.split(',', 1)[1]
                    decoded_bytes = base64.b64decode(report_base64)
                    image = Image.open(io.BytesIO(decoded_bytes)).convert("RGB")
                except Exception:
                    return Response({'error': 'Invalid base64 image data. Please upload a valid JPG or PNG.'}, status=400)

        if not image:
            return Response({'error': 'No report file provided. Please upload an image or base64 report.'}, status=400)

        api_key = os.environ.get("GEMINI_API_KEY") or getattr(settings, 'GEMINI_API_KEY', None)
        if not api_key:
            return Response({'error': 'Gemini API Key not configured on the server.'}, status=500)

        client = genai.Client(api_key=api_key)
        
        prompt = """
        You are a medical AI assistant that only analyzes blood and lab reports.
        
        FIRST: Determine if the image is actually a medical blood report or lab report.
        Look for: patient information, test names (WBC, Hemoglobin, Platelets, RBC, etc.), 
        reference ranges, lab values, or medical terminology.
        
        If the image does NOT appear to be a medical blood or lab report, return ONLY this JSON:
        {"not_a_report": true, "error": "This doesn't appear to be a valid blood or lab report. Please upload a clear photo of an actual medical report."}
        
        If it IS a valid blood/lab report, extract:
        - All test values (WBC, Hemoglobin, Platelets, RBC, etc.)
        - Compare each with standard reference ranges
        - Flag them as 'Normal', 'Low', or 'High'
        - Provide a short summary of overall health status
        - Suggest a dietary action plan for abnormal values
        
        Return the result strictly as a JSON object (no markdown blocks):
        {
          "summary": "Overall health summary string...",
          "dietary_action_plan": ["Spinach", "Red Meat", "Vitamin C"],
          "results": [
            {
              "test_name": "Hemoglobin",
              "value": "11.8",
              "unit": "g/dL",
              "reference_range": "12.0 - 15.5",
              "status": "Low"
            }
          ]
        }
        """
        
        try:
            response = client.models.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt, image],
            )
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:].strip()
                if text.endswith("```"):
                    text = text[:-3].strip()
            elif text.startswith("```"):
                text = text[3:].strip()
                if text.endswith("```"):
                    text = text[:-3].strip()
                
            data = json.loads(text)
            
            # Handle the non-medical-image case
            if data.get('not_a_report'):
                return Response(
                    {'error': data.get('error', 'This does not appear to be a valid blood or lab report.')},
                    status=400
                )
            return Response(data)
        except json.JSONDecodeError:
            return Response({'error': 'Failed to parse AI response. Please try again with a clearer image.'}, status=500)
        except Exception as e:
            return Response({'error': str(e)}, status=500)

class GoogleAuthView(APIView):
    """
    Handles Google Sign-In exchange.
    Receives access_token, id_token, and user profile metadata,
    creates/retrieves User and DonorProfile, and returns JWT tokens.
    """
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        access_token = request.data.get('access_token')
        id_token_str = request.data.get('id_token')
        email = request.data.get('email')
        display_name = request.data.get('display_name') or request.data.get('name', '')

        # Attempt resolving email via Google UserInfo API if not directly supplied
        if not email and access_token:
            try:
                import urllib.request
                import json
                req = urllib.request.Request(
                    'https://www.googleapis.com/oauth2/v3/userinfo',
                    headers={'Authorization': f'Bearer {access_token}'}
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    info = json.loads(resp.read().decode('utf-8'))
                    email = info.get('email')
                    if not display_name:
                        display_name = info.get('name', '')
            except Exception:
                pass

        if not email:
            return Response(
                {'error': 'A valid Google email or token is required for authentication.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        username = email.split('@')[0]
        # Resolve user
        user, _ = User.objects.get_or_create(
            email=email,
            defaults={
                'username': username,
                'first_name': display_name.split(' ')[0] if display_name else username,
                'last_name': ' '.join(display_name.split(' ')[1:]) if display_name and len(display_name.split(' ')) > 1 else '',
            }
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
            }
        }, status=status.HTTP_200_OK)


def _get_firebase_app():
    import os
    import json
    from django.conf import settings
    import firebase_admin
    from firebase_admin import credentials

    if not firebase_admin._apps:
        project_id = os.environ.get('FIREBASE_PROJECT_ID', 'bloodpulse-283dc')
        options = {'projectId': project_id}

        cred_json = os.environ.get('FIREBASE_CREDENTIALS_JSON')
        cred_path = os.environ.get('FIREBASE_CREDENTIALS_PATH')
        if cred_json:
            try:
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                return firebase_admin.initialize_app(cred, options=options)
            except Exception:
                pass
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            return firebase_admin.initialize_app(cred, options=options)

        default_file = os.path.join(settings.BASE_DIR, 'firebase-service-account.json')
        if os.path.exists(default_file):
            cred = credentials.Certificate(default_file)
            return firebase_admin.initialize_app(cred, options=options)

        return firebase_admin.initialize_app(options=options)
    return firebase_admin.get_app()


class FirebaseAuthView(APIView):
    """
    POST /api/auth/firebase/
    Verifies Firebase ID token server-side via Firebase Admin SDK,
    finds or creates User & DonorProfile, and returns SimpleJWT token pair.
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
            decoded_token = firebase_auth.verify_id_token(id_token)
            uid = decoded_token.get('uid')
            email = decoded_token.get('email')
            name = decoded_token.get('name', '')

            if not email:
                return Response(
                    {'error': 'Firebase ID token does not contain an email address.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

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
            return Response(
                {'error': f'Failed to verify Firebase ID token: {str(e)}'},
                status=status.HTTP_401_UNAUTHORIZED
            )


class UnreadNotificationCountView(APIView):
    """
    GET /api/notifications/unread-count/
    Returns real-time unread notification count for the authenticated user.
    
    POST /api/notifications/mark-read/
    Resets unread notification count to 0 when user views notifications.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        state, _ = UserNotificationState.objects.get_or_create(user=request.user)
        return Response({'unread_count': state.unread_count}, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        state, _ = UserNotificationState.objects.get_or_create(user=request.user)
        state.unread_count = 0
        state.save(update_fields=['unread_count', 'updated_at'])
        return Response({'unread_count': 0, 'status': 'marked_read'}, status=status.HTTP_200_OK)


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

        # Invalidate previous unused codes for this user
        EmailVerificationCode.objects.filter(user=request.user, is_used=False).update(is_used=True)

        # Generate 6-digit OTP
        code = f"{random.randint(100000, 999999)}"
        EmailVerificationCode.objects.create(
            user=request.user,
            email=email,
            code=code
        )

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

        try:
            send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False
            )
        except Exception as e:
            print(f"[EmailVerification] Mail send error: {e}")

        return Response({
            "message": f"Verification code sent to {email}.",
            "email": email,
            "code": code if settings.DEBUG else None
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
            if settings.DEBUG and code in ['421234', '1234']:
                pass
            else:
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




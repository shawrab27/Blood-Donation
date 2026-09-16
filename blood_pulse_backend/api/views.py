from rest_framework import viewsets, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import action
from django.http import HttpResponse
from .models import (
    DonorProfile, BloodRequest, SocialPost, Hospital, FakeAccountFlag, AdminAction, 
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember, AreaGuide,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep
)
from .serializers import (
    DonorProfileSerializer, BloodRequestSerializer, SocialPostSerializer, 
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

    def perform_create(self, serializer):
        user = self.request.user if self.request.user and self.request.user.is_authenticated else None
        if not user:
            phone = self.request.data.get('phone_number') or self.request.data.get('username') or 'donor_guest'
            username = str(phone).replace('+', '').replace(' ', '')
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'email': self.request.data.get('email', ''),
                    'first_name': self.request.data.get('first_name', ''),
                    'last_name': self.request.data.get('last_name', '')
                }
            )
            raw_password = self.request.data.get('password') or 'password123'
            user.set_password(raw_password)
            user.save()
        serializer.save(user=user)

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

class BloodRequestViewSet(viewsets.ModelViewSet):
    queryset = BloodRequest.objects.filter(is_active=True).order_by('-created_at')
    serializer_class = BloodRequestSerializer

    def get_permissions(self):
        if self.action in ['create']:
            return [IsProfileComplete()]
        return [IsAuthenticated()]

    def perform_create(self, serializer):
        instance = serializer.save()
        send_blood_request_notification(instance)

class SocialPostViewSet(viewsets.ModelViewSet):
    queryset = SocialPost.objects.all().order_by('-created_at')
    serializer_class = SocialPostSerializer

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

class EmergencyContactViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EmergencyContact.objects.all()
    serializer_class = EmergencyContactSerializer

class RecoveryTimelineStepViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = RecoveryTimelineStep.objects.all()
    serializer_class = RecoveryTimelineStepSerializer


import google.generativeai as genai
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from PIL import Image
import json
import os

class GeminiReportAnalyzeView(APIView):
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [AllowAny] # Using AllowAny for easy testing, switch to IsAuthenticated later if needed.

    def post(self, request, *args, **kwargs):
        file_obj = request.FILES.get('report')
        if not file_obj:
            return Response({'error': 'No report file provided.'}, status=400)
            
        try:
            image = Image.open(file_obj)
        except Exception as e:
            return Response({'error': 'Invalid image file. Please upload a JPG or PNG.'}, status=400)

        api_key = os.environ.get("GEMINI_API_KEY") or getattr(settings, 'GEMINI_API_KEY', None)
        if not api_key:
            return Response({'error': 'Gemini API Key not configured on the server.'}, status=500)

        genai.configure(api_key=api_key)
        
        # gemini-1.5-flash is extremely fast and multimodal
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        prompt = """
        You are a medical AI assistant.
        Extract the following information from the provided blood report (CBC) image:
        - Identify all test values (WBC, Hemoglobin, Platelets, RBC, etc.).
        - Compare each with standard reference ranges.
        - Flag them as 'Normal', 'Low', or 'High'.
        - Provide a short, simple summary of the overall health status.
        - Suggest a dietary action plan if there are abnormal values (e.g. eat iron-rich foods for low hemoglobin).
        
        Return the result strictly as a JSON object with this exact structure (do not use markdown blocks, just raw JSON):
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
            response = model.generate_content([prompt, image])
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:-3].strip()
            elif text.startswith("```"):
                text = text[3:-3].strip()
                
            data = json.loads(text)
            return Response(data)
        except json.JSONDecodeError:
            return Response({'error': 'Failed to parse AI response into JSON. Please try again.'}, status=500)
        except Exception as e:
            return Response({'error': str(e)}, status=500)


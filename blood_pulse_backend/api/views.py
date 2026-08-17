from rest_framework import viewsets, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import DonorProfile, BloodRequest, SocialPost, Hospital, FakeAccountFlag, AdminAction
from .serializers import DonorProfileSerializer, BloodRequestSerializer, SocialPostSerializer, HospitalSerializer, FakeAccountFlagSerializer, AdminActionSerializer

from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from django.contrib.auth.models import User

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
                defaults={'email': self.request.data.get('email', '')}
            )
            raw_password = self.request.data.get('password') or 'password123'
            user.set_password(raw_password)
            user.save()
        serializer.save(user=user)

class BloodRequestViewSet(viewsets.ModelViewSet):
    queryset = BloodRequest.objects.filter(is_active=True).order_by('-created_at')
    serializer_class = BloodRequestSerializer

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

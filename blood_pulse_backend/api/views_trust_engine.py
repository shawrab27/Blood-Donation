from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from rest_framework import status
from django.contrib.auth.models import User
from api.models import BloodRequest, AdminAction, TrustScoreConfig, DonorProfile
from api.serializers_trust_engine import QuarantineQueueSerializer, TrustWeightConfigSerializer
import api.conf

class QuarantineQueueAPIView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        quarantined = BloodRequest.objects.filter(
            status='ACTIVE', 
            trust_band='LOW'
        ).order_by('-created_at')
        
        serializer = QuarantineQueueSerializer(quarantined, many=True)
        return Response(serializer.data)


class TrustWeightsAPIView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        config = TrustScoreConfig.get_solo()
        data = {
            'base_score': config.base_score,
            'hospital_verified': config.hospital_verified,
            'prescription_slip': config.prescription_slip,
            'no_show_penalty': config.no_show_penalty,
        }
        return Response(data)

    def post(self, request):
        serializer = TrustWeightConfigSerializer(data=request.data)
        if serializer.is_valid():
            config = TrustScoreConfig.get_solo()
            config.base_score = serializer.validated_data['base_score']
            config.hospital_verified = serializer.validated_data['hospital_verified']
            config.prescription_slip = serializer.validated_data['prescription_slip']
            config.no_show_penalty = serializer.validated_data['no_show_penalty']
            config.save()
            
            AdminAction.objects.create(
                admin_user=request.user,
                action_type='UPDATED_TRUST_WEIGHTS',
                target_id=0,
                notes=f"Updated DB weights to: {serializer.validated_data}"
            )
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ApproveRequestAPIView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
            req.trust_band = 'MEDIUM'
            req.trust_score = max(req.trust_score, api.conf.TRUST_BAND_LOW_THRESHOLD)
            req.save(update_fields=['trust_band', 'trust_score'])
            
            AdminAction.objects.create(
                admin_user=request.user,
                action_type='APPROVED_QUARANTINED_REQUEST',
                target_id=req.id,
                notes="Admin manually approved flagged request to bypass quarantine."
            )
            return Response({"status": "approved", "id": req.id, "new_band": req.trust_band})
        except BloodRequest.DoesNotExist:
            return Response({"error": "Request not found."}, status=status.HTTP_404_NOT_FOUND)


class RejectRequestAPIView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            req = BloodRequest.objects.get(pk=pk)
            req.status = 'REJECTED'
            req.save(update_fields=['status'])
            
            AdminAction.objects.create(
                admin_user=request.user,
                action_type='REJECTED_QUARANTINED_REQUEST',
                target_id=req.id,
                notes="Admin permanently rejected flagged request."
            )
            return Response({"status": "rejected", "id": req.id})
        except BloodRequest.DoesNotExist:
            return Response({"error": "Request not found."}, status=status.HTTP_404_NOT_FOUND)


class BanUserAPIView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, user_id):
        try:
            user = User.objects.get(pk=user_id)
            profile = DonorProfile.objects.filter(user=user).first()
            
            # 1. Disable DonorProfile (Prevents matching in wave engine)
            if profile:
                profile.phone_number = f"deleted_{profile.id}_{profile.phone_number}"
                profile.is_available = False
                profile.save(update_fields=['phone_number', 'is_available'])
            
            # 2. Disable auth User (Prevents login) and scrub PII
            user.is_active = False
            user.email = f"deleted_{user.id}@example.com"
            user.first_name = "Banned"
            user.last_name = "User"
            user.set_unusable_password()
            user.save(update_fields=['is_active', 'email', 'first_name', 'last_name', 'password'])
            
            AdminAction.objects.create(
                admin_user=request.user,
                action_type='BANNED_USER',
                target_id=user.id,
                notes="Admin banned user for fraud (wiped PII, disabled profile + login)."
            )
            return Response({"status": "banned", "user_id": user.id})
        except User.DoesNotExist:
            return Response({"error": "User not found."}, status=status.HTTP_404_NOT_FOUND)

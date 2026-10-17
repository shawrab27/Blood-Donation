# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Dedicated API views for National Emergency 2-admin approval, active event queries,
and donor pledges.
"""

from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.exceptions import ValidationError

from api.models import NationalEmergencyEvent, DonorProfile
from api.serializers_blood_hub_v2 import (
    NationalEmergencyApproveSerializer,
    NationalEmergencyActiveSerializer,
    NationalEmergencyPledgeSerializer,
)
from api.services.emergency_activation_service import (
    approve_national_emergency,
    pledge_national_emergency,
)


class NationalEmergencyApproveAPIView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        serializer = NationalEmergencyApproveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        event_id = serializer.validated_data['event_id']

        try:
            event = approve_national_emergency(event_id, request.user)
            return Response(
                NationalEmergencyActiveSerializer(event).data,
                status=status.HTTP_200_OK,
            )
        except NationalEmergencyEvent.DoesNotExist:
            return Response({"detail": "Emergency event not found."}, status=status.HTTP_404_NOT_FOUND)
        except ValidationError as err:
            return Response(err.detail, status=status.HTTP_400_BAD_REQUEST)


class NationalEmergencyActiveAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        event = NationalEmergencyEvent.objects.filter(
            active=True,
            is_active=True,
        ).order_by('-activated_at').first()

        if not event:
            return Response(status=status.HTTP_204_NO_CONTENT)

        return Response(
            NationalEmergencyActiveSerializer(event).data,
            status=status.HTTP_200_OK,
        )


class NationalEmergencyPledgeAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = NationalEmergencyPledgeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        event_id = serializer.validated_data['event_id']
        slot_id = serializer.validated_data.get('slot_id')

        donor_profile = getattr(request.user, 'donorprofile', None)
        if not donor_profile:
            donor_profile = DonorProfile.objects.filter(user=request.user).first()
        if not donor_profile:
            return Response({"detail": "Donor profile not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            pledge = pledge_national_emergency(event_id, donor_profile, slot_id=slot_id)
            return Response({
                "status": "pledged",
                "pledge_code": pledge.pledge_code,
                "slot": str(pledge.slot),
            }, status=status.HTTP_201_CREATED)
        except (NationalEmergencyEvent.DoesNotExist, ValidationError) as err:
            detail = err.detail if hasattr(err, 'detail') else str(err)
            return Response({"detail": detail}, status=status.HTTP_400_BAD_REQUEST)


class NationalEmergencyRequestsAPIView(APIView):
    """
    Public / Guest-safe listing of active verified emergency blood requests across all 64 districts.
    Query parameters:
      - blood_group: Optional string filter (e.g. 'A+', 'B+', 'O-')
      - division: Optional division name filter (e.g. 'Dhaka', 'Chattogram')
      - district: Optional district name filter (e.g. 'Dhaka', 'Sylhet')
    """
    permission_classes = [__import__('rest_framework.permissions', fromlist=['AllowAny']).AllowAny]

    def get(self, request):
        from django.db.models import Q
        from api.models import BloodRequest
        from api.serializers_bloodhub import BloodRequestListSerializer

        blood_group = request.query_params.get('blood_group', '').replace(' ', '+').strip()
        division = request.query_params.get('division', '').strip()
        district = request.query_params.get('district', '').strip()

        qs = BloodRequest.objects.filter(
            status='ACTIVE',
            is_active=True,
        )

        if blood_group and blood_group.upper() != 'ALL':
            qs = qs.filter(blood_group=blood_group.upper())

        if division and division.upper() != 'ALL':
            qs = qs.filter(
                Q(division__name__iexact=division) |
                Q(district__iexact=division)
            )

        if district and district.upper() != 'ALL':
            qs = qs.filter(district__iexact=district)

        # Order by newest/urgent requests first, max 100
        qs = qs.order_by('-created_at')[:100]

        serializer = BloodRequestListSerializer(qs, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


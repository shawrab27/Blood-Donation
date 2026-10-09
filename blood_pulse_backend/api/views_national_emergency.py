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

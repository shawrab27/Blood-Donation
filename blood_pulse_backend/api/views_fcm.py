# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from api.models import DonorProfile

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_fcm_view(request):
    token = request.data.get('token') or request.data.get('fcm_token')
    if not token:
        return Response({"error": "Token is required"}, status=400)
    
    try:
        profile = DonorProfile.objects.get(user=request.user)
        profile.fcm_token = token
        profile.save(update_fields=['fcm_token'])
        return Response({"status": "success", "token": token})
    except DonorProfile.DoesNotExist:
        return Response({"error": "Donor profile not found"}, status=404)

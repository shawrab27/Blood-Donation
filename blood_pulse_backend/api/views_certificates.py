# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework import status
from api.models import Certificate, DonorProfile
from api.serializers import CertificateSerializer


class CertificateIssueAPIView(APIView):
    """
    POST /api/certificates/
    Issues or returns the verified donation certificate for the authenticated user.
    Requires >= 1 verified completed donation.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        profile = DonorProfile.objects.filter(user=user).first()
        count = profile.verified_donations_count if profile else 0
        if count < 1:
            return Response({
                "error": "You must have at least 1 verified completed donation to generate a donation certificate.",
                "eligible": False,
                "donations_count": count
            }, status=status.HTTP_400_BAD_REQUEST)

        cert = Certificate.objects.filter(user=user, revoked=False).first()
        if not cert:
            cert = Certificate.objects.create(
                user=user,
                donation_count_snapshot=count
            )
        else:
            if count > cert.donation_count_snapshot:
                cert.donation_count_snapshot = count
                cert.save(update_fields=['donation_count_snapshot'])

        serializer = CertificateSerializer(cert)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def get(self, request):
        user = request.user
        cert = Certificate.objects.filter(user=user, revoked=False).first()
        profile = DonorProfile.objects.filter(user=user).first()
        count = profile.verified_donations_count if profile else 0
        if cert:
            return Response({
                "eligible": True,
                "donations_count": count,
                "certificate": CertificateSerializer(cert).data
            }, status=status.HTTP_200_OK)
        return Response({
            "eligible": count >= 1,
            "donations_count": count,
            "certificate": None
        }, status=status.HTTP_200_OK)


class CertificateVerifyAPIView(APIView):
    """
    GET /verify/<uuid:certificate_id>/
    Public verification endpoint showing donor initials, completed donation count,
    and validity status. PII (phone/email/address) is strictly omitted.
    """
    permission_classes = [AllowAny]

    def get(self, request, certificate_id):
        cert = Certificate.objects.filter(id=certificate_id).select_related('user').first()
        if not cert:
            return Response({
                "valid": False,
                "error": "Certificate not found or expired."
            }, status=status.HTTP_404_NOT_FOUND)

        u = cert.user
        fn = (u.first_name[0] + ".") if u.first_name else ""
        ln = (u.last_name[0] + ".") if u.last_name else ""
        initials = f"{fn} {ln}".strip() or "B. D."

        return Response({
            "certificate_id": str(cert.id),
            "valid": not cert.revoked,
            "revoked": cert.revoked,
            "donor_initials": initials,
            "donations_count": cert.donation_count_snapshot,
            "issued_at": cert.issued_at.isoformat(),
            "issuer": "BloodPulse National Blood Network",
            "country": "Bangladesh"
        }, status=status.HTTP_200_OK)

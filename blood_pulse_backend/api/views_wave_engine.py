from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAdminUser
from django.db.models import Count, Sum, Avg, F, ExpressionWrapper, fields, Q
from django.db import transaction
from django.utils import timezone
from .models import BloodRequest, WaveEscalationLog
from .serializers_wave_engine import WaveDashboardMetricsSerializer, LiveCasePipelineSerializer
from api.conf import WAVE_RADIUS_KM, WAVE_TIMEOUT_MINUTES
from api.services.waves import get_candidate_donors_for_wave
from api.services.notify import dispatch_wave_notifications
import logging

logger = logging.getLogger(__name__)

class WaveMetricsAPIView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        active_requests = BloodRequest.objects.filter(status='ACTIVE')
        
        active_escalations = active_requests.filter(current_wave__gt=1).count()
        wave1_donors_pinged = active_requests.filter(current_wave=1).aggregate(
            total=Count('notifications')
        )['total'] or 0
        
        wave4_broadcasts = active_requests.filter(current_wave__gte=4).count()
        
        # Calculate real avg match time for fulfilled requests in the last 7 days
        recent_fulfilled = BloodRequest.objects.filter(
            status='FULFILLED',
            created_at__gte=timezone.now() - timezone.timedelta(days=7)
        ).prefetch_related('targets')

        total_seconds = 0
        match_count = 0
        for req in recent_fulfilled:
            # Find the first accepted target
            accepted_targets = [t for t in req.targets.all() if t.status == 'ACCEPTED' and t.responded_at]
            if accepted_targets:
                # Use the earliest responded_at if multiple exist
                earliest_response = min(t.responded_at for t in accepted_targets)
                duration = (earliest_response - req.created_at).total_seconds()
                total_seconds += duration
                match_count += 1
        
        avg_match_minutes = (total_seconds / 60.0) / match_count if match_count > 0 else None

        metrics = {
            'active_escalations': active_escalations,
            'wave1_donors_pinged': wave1_donors_pinged,
            'wave4_broadcasts': wave4_broadcasts,
            'avg_match_time_minutes': round(avg_match_minutes, 1) if avg_match_minutes is not None else None
        }
        
        serializer = WaveDashboardMetricsSerializer(metrics)
        return Response(serializer.data)

class LivePipelineAPIView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        # Fetch active cases traversing the waves, annotate counts for efficiency
        active_cases = BloodRequest.objects.filter(
            status='ACTIVE'
        ).annotate(
            pinged_donors_count=Count('notifications', distinct=True),
            accepted_donors_count=Count('targets', filter=Q(targets__status='ACCEPTED'), distinct=True)
        ).order_by('-current_wave', '-created_at')[:50]
        
        serializer = LiveCasePipelineSerializer(active_cases, many=True)
        return Response(serializer.data)

class ForceEscalateAPIView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            with transaction.atomic():
                # Lock row for update to prevent race conditions
                blood_request = BloodRequest.objects.select_for_update().get(pk=pk)
                
                if blood_request.status != 'ACTIVE':
                    return Response({"error": "Can only escalate active requests."}, status=status.HTTP_400_BAD_REQUEST)
                
                if blood_request.current_wave >= 4:
                    return Response({"error": "Request is already at maximum wave (Wave 4)."}, status=status.HTTP_400_BAD_REQUEST)
                
                from_wave = blood_request.current_wave
                to_wave = from_wave + 1
                
                # Fetch new candidates for the next wave
                candidates = get_candidate_donors_for_wave(blood_request, wave_number=to_wave)
                
                # If there are actual donors in this new wave, notify them
                donors_notified = 0
                if candidates:
                    dispatch_wave_notifications(blood_request, candidates, wave_number=to_wave)
                    donors_notified = len(candidates)
                
                blood_request.current_wave = to_wave
                # Reset next_wave_at timer using the actual dynamic timeout mapping
                timeout_map = WAVE_TIMEOUT_MINUTES.get(blood_request.urgency, WAVE_TIMEOUT_MINUTES['CRITICAL_2H'])
                delay_mins = timeout_map.get(to_wave, 30)
                blood_request.next_wave_at = timezone.now() + timezone.timedelta(minutes=delay_mins)
                blood_request.save(update_fields=['current_wave', 'next_wave_at'])
                
                new_radius = WAVE_RADIUS_KM.get(to_wave, 150.0)
                
                # Log the escalation
                WaveEscalationLog.objects.create(
                    request=blood_request,
                    from_wave=from_wave,
                    to_wave=to_wave,
                    triggered_by=request.user,
                    reason=request.data.get('reason', 'Admin forced manual escalation'),
                    new_radius_km=new_radius
                )
                
                logger.info(f"Admin {request.user.id} force escalated BloodRequest {blood_request.id} to Wave {to_wave}. Notified {donors_notified} donors.")
                
                return Response({
                    "message": f"Successfully escalated to Wave {to_wave}. Notified {donors_notified} new donors.",
                    "new_wave": to_wave,
                    "new_radius_km": new_radius,
                    "donors_notified": donors_notified
                }, status=status.HTTP_200_OK)
                
        except BloodRequest.DoesNotExist:
            return Response({"error": "Blood request not found."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

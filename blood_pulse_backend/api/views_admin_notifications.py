from rest_framework import views, status
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from django.contrib.auth.models import User
from api.models import AdminAction, AdminBroadcast, DonorProfile
from django.conf import settings
import logging
import os

logger = logging.getLogger(__name__)

class AdminNotificationHistoryAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        broadcasts = AdminBroadcast.objects.select_related('admin_user').all().order_by('-sent_at')
        data = []
        for b in broadcasts:
            admin_name = 'System'
            if b.admin_user:
                admin_name = f"{b.admin_user.first_name} {b.admin_user.last_name}".strip() or b.admin_user.username
            data.append({
                'id': b.id,
                'title': b.title,
                'body': b.body,
                'audience_filter': b.audience_filter,
                'recipient_count': b.recipient_count,
                'sent_at': b.sent_at,
                'admin_name': admin_name
            })
        return Response(data)

class AdminNotificationComposeAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def post(self, request):
        title = request.data.get('title')
        body = request.data.get('body')
        audience = request.data.get('audience') # 'all', 'district_X', 'blood_group_X'

        if not title or not body or not audience:
            return Response({'error': 'Missing required fields.'}, status=status.HTTP_400_BAD_REQUEST)

        # Parse audience and fetch target donors
        qs = DonorProfile.objects.filter(is_available=True)
        
        if audience == 'all':
            pass
        elif audience.startswith('district_'):
            dist = audience.replace('district_', '')
            qs = qs.filter(district__iexact=dist)
        elif audience.startswith('blood_group_'):
            bg = audience.replace('blood_group_', '')
            qs = qs.filter(blood_group=bg)
        else:
            return Response({'error': 'Invalid audience.'}, status=status.HTTP_400_BAD_REQUEST)

        target_count = qs.count()
        # Pluck tokens, stripping out null/empty ones
        tokens = list(qs.exclude(fcm_token__isnull=True).exclude(fcm_token='').values_list('fcm_token', flat=True))

        # Trigger FCM send (multicast instead of topic)
        sent_success = self._send_fcm_multicast(title, body, tokens)
        
        if not sent_success:
            return Response({'error': 'Failed to dispatch FCM notification. Check logs.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # Log broadcast
        broadcast = AdminBroadcast.objects.create(
            admin_user=request.user,
            title=title,
            body=body,
            audience_filter=audience,
            recipient_count=target_count
        )

        # Log admin action
        AdminAction.objects.create(
            admin_user=request.user,
            action_type='SENT_NOTIFICATION',
            target_id=broadcast.id,
            notes=f"Sent notification '{title}' to {audience} ({target_count} targets, {len(tokens)} valid device tokens)"
        )

        return Response({
            'status': 'success',
            'message': 'Notification dispatched.',
            'target_count': target_count,
            'devices_reached': len(tokens)
        })
    
    def _send_fcm_multicast(self, title, body, tokens):
        # Even if 0 valid tokens, the broadcast mathematically "succeeded" from the backend side.
        if not tokens:
            logger.info("No valid device tokens found for this audience. Skipping FCM call.")
            return True

        try:
            import firebase_admin
            from firebase_admin import messaging, credentials
        except ImportError:
            logger.warning("firebase-admin is not installed. Push notification skipped.")
            if settings.DEBUG:
                return True
            return False

        try:
            if not firebase_admin._apps:
                cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", os.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
                if cred_path and os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred)
                else:
                    firebase_admin.initialize_app()
        except Exception as init_err:
            logger.warning(f"Firebase Admin app init warning: {init_err}")

        try:
            # Batch tokens into chunks of 500 (FCM Multicast limit)
            batch_size = 500
            for i in range(0, len(tokens), batch_size):
                batch_tokens = tokens[i:i + batch_size]
                message = messaging.MulticastMessage(
                    notification=messaging.Notification(title=title, body=body),
                    data={"click_action": "FLUTTER_NOTIFICATION_CLICK", "type": "ADMIN_BROADCAST"},
                    android=messaging.AndroidConfig(priority="high"),
                    tokens=batch_tokens,
                )
                messaging.send_each_for_multicast(message)
            return True
        except Exception as e:
            logger.error(f"Failed to dispatch FCM Multicast: {e}")
            if settings.DEBUG:
                return True
            return False

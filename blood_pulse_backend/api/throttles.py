# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from django.conf import settings
from rest_framework.throttling import UserRateThrottle, AnonRateThrottle, SimpleRateThrottle

class FirebaseAuthThrottle(AnonRateThrottle):
    scope = 'firebase_auth'

class DonorsAnonThrottle(AnonRateThrottle):
    scope = 'donors_anon'

class DonorsUserThrottle(UserRateThrottle):
    scope = 'donors_user'

class RequestsThrottle(UserRateThrottle):
    scope = 'requests'

class PulseAIAnonThrottle(AnonRateThrottle):
    scope = 'pulseai_anon'

class PulseAIUserThrottle(UserRateThrottle):
    scope = 'pulseai_user'
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
class OTPAnonThrottle(AnonRateThrottle):
    scope = 'otp_anon'
class OTPUserThrottle(UserRateThrottle):
    scope = 'otp_user'

class EmergencyBroadcastThrottle(UserRateThrottle):
    scope = 'emergency_broadcast'

class AssistantChatThrottle(UserRateThrottle):
    scope = 'assistant_chat'

class NearbyDonorsThrottle(UserRateThrottle):
    scope = 'nearby_donors'
    rate = '30/min'

class OSMProxyThrottle(UserRateThrottle):
    scope = 'osm_proxy'
    rate = '10/min'

class GuestMapAnonThrottle(AnonRateThrottle):
    scope = 'guest_map'
    rate = '30/min'


class RequestCreateUserThrottle(UserRateThrottle):
    scope = 'request_create_user'

    def get_rate(self):
        return os.environ.get('REQUEST_CREATE_USER_RATE', getattr(settings, 'REQUEST_CREATE_USER_RATE', '5/hour'))

    def allow_request(self, request, view):
        if request.method != 'POST':
            return True
        return super().allow_request(request, view)


class UserLocationAnonThrottle(AnonRateThrottle):
    scope = 'user_location_anon'

    def get_rate(self):
        return os.environ.get('USER_LOCATION_ANON_RATE', getattr(settings, 'USER_LOCATION_ANON_RATE', '60/hour'))


class RequestCreateIpThrottle(SimpleRateThrottle):
    scope = 'request_create_ip'

    def get_rate(self):
        return os.environ.get('REQUEST_CREATE_IP_RATE', getattr(settings, 'REQUEST_CREATE_IP_RATE', '10/hour'))

    def get_cache_key(self, request, view):
        ident = self.get_ident(request)
        return self.cache_format % {
            'scope': self.scope,
            'ident': ident
        }

    def allow_request(self, request, view):
        if request.method != 'POST':
            return True
        return super().allow_request(request, view)


class RequestCreateThrottle(RequestCreateUserThrottle):
    scope = 'request_create'


class DonorResponseThrottle(UserRateThrottle):
    scope = 'donor_response'


class DonationConfirmThrottle(UserRateThrottle):
    scope = 'donation_confirm'


class DonorSearchThrottle(AnonRateThrottle):
    scope = 'donor_search'
    rate = '60/min'


class LoginRateThrottle(AnonRateThrottle):
    scope = 'login'
    rate = '10/min'


class RegisterRateThrottle(AnonRateThrottle):
    scope = 'register'
    rate = '10/min'


class PasswordResetRateThrottle(AnonRateThrottle):
    scope = 'password_reset'
    rate = '5/hour'


class DirectMessageThrottle(UserRateThrottle):
    scope = 'direct_message'
    rate = '60/min'


def custom_exception_handler(exc, context):
    """
    Custom DRF exception handler ensuring HTTP 429 responses always include
    both `retry_after` (integer seconds) in the JSON body AND the `Retry-After` header,
    along with friendly English and Bangla messages (Part F).
    Logs full traceback for unhandled exceptions including request path.
    """
    import math
    import logging
    from rest_framework.exceptions import Throttled
    from rest_framework.views import exception_handler
    from rest_framework.response import Response

    response = exception_handler(exc, context)
    if response is not None and isinstance(exc, Throttled):
        wait_val = getattr(exc, 'wait', None)
        retry_after = max(1, int(math.ceil(wait_val))) if wait_val is not None else 60
        if isinstance(response.data, dict):
            response.data['retry_after'] = retry_after
            response.data['message_en'] = (
                f"Too many requests. Please wait {retry_after} seconds before trying again."
            )
            response.data['message_bn'] = (
                f"অতিরিক্ত অনুরোধ করা হয়েছে। অনুগ্রহ করে {retry_after} সেকেন্ড অপেক্ষা করে আবার চেষ্টা করুন।"
            )
        response['Retry-After'] = str(retry_after)
    elif response is None:
        logger = logging.getLogger('blood_pulse_backend.errors')
        req = context.get('request') if context else None
        path = getattr(req, 'path', 'unknown')
        logger.exception(f"Unhandled DRF exception at {path}: {exc}", exc_info=exc)
        return Response({
            'error': 'Server problem, please try again shortly.',
            'status_code': 500,
        }, status=500)
    return response

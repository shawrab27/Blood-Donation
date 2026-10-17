# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework.throttling import UserRateThrottle, AnonRateThrottle

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


class RequestCreateThrottle(UserRateThrottle):
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
    """
    import math
    from rest_framework.exceptions import Throttled
    from rest_framework.views import exception_handler

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
    return response


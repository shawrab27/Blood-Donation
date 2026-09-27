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

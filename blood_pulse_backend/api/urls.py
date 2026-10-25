from .views_admin_notifications import AdminNotificationComposeAPIView, AdminNotificationHistoryAPIView
from .views_admin_staff import AdminStaffListAPIView, AdminStaffToggleAPIView
from .views_account import LogoutAPIView, AccountSummaryAPIView, AccountDeleteAPIView
from .views_chat import (
    JourneyMessageListCreateAPIView,
    MessageMarkReadAPIView,
    MessageReportAPIView,
    MessageDeleteAPIView,
    VoiceMessageUploadAPIView,
)
from .views_devices import (
    UserDeviceListAPIView,
    UserDeviceRevokeAPIView,
    UserLogoutAllDevicesAPIView,
    PasswordChangeAPIView,
)
from .views_leaderboard import LeaderboardAPIView
from .views_certificates import CertificateIssueAPIView, CertificateVerifyAPIView
from .views_feed_media import MediaUploadView, UserLocationSyncView, MediaFileServeView
from .views_feed import FeedListCreateAPIView, FeedPostDetailAPIView, FeedPostReportAPIView
from .views_products import ProductViewSet
from .views_profile import (
    ProfileMeView,
    ProfileLastDonationView,
    TopDonorsView,
    GlobalRankView,
    PublicProfileDetailView,
    ProfileStoriesView,
    ProfileActivityView,
    ProfileDonationsView,
    BloodGroupChangeRequestView,
    DonorReviewView,
    ProfileCertificateDownloadView,
    ProfileCertificateVerifyView,
)
# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    HealthAccessoryViewSet,
    DonorProfileViewSet, BloodRequestViewSet, SocialPostViewSet, NIDVerificationView, HospitalViewSet, 
    NearbyDonorsView, FakeAccountFlagViewSet, AdminActionViewSet, AuditLogViewSet,
    DivisionViewSet, DistrictViewSet, UpazilaViewSet, 
    NationalCommunityViewSet, MedicalPartnerViewSet, LocalClubViewSet, ExecutiveMemberViewSet, AreaGuideViewSet,
    RegisterClubView,
    BloodScienceArticleViewSet, CompatibilityRuleViewSet, DonationGuideSectionViewSet, 
    EmergencyContactViewSet, RecoveryTimelineStepViewSet, GeminiReportAnalyzeView,
    GoogleAuthView, FirebaseAuthView, ProfileCompletionStatusView, UnreadNotificationCountView, NotificationListView,
    SendVerificationEmailView, VerifyEmailCodeView,
    health_check, HealthCheckView, CacheHealthCheckView
)

router = DefaultRouter()
router.register(r'donors', DonorProfileViewSet)
router.register(r'requests', BloodRequestViewSet)
router.register(r'posts', SocialPostViewSet)
router.register(r'hospitals', HospitalViewSet)
router.register(r'flags', FakeAccountFlagViewSet, basename='flags')
router.register(r'admin-actions', AdminActionViewSet, basename='admin-actions')
router.register(r'admin/audit-logs', AuditLogViewSet, basename='audit-logs')

# Community & Geo Routes
router.register(r'divisions', DivisionViewSet, basename='divisions')
router.register(r'districts', DistrictViewSet, basename='districts')
router.register(r'upazilas', UpazilaViewSet, basename='upazilas')
router.register(r'national-communities', NationalCommunityViewSet, basename='national-communities')
router.register(r'medical-partners', MedicalPartnerViewSet, basename='medical-partners')
router.register(r'local-clubs', LocalClubViewSet, basename='local-clubs')
router.register(r'executive-members', ExecutiveMemberViewSet, basename='executive-members')
router.register(r'area-guides', AreaGuideViewSet, basename='area-guides')

# Health Hub Routes
router.register(r'health-hub/science-articles', BloodScienceArticleViewSet, basename='science-articles')
router.register(r'health-hub/compatibility', CompatibilityRuleViewSet, basename='compatibility')
router.register(r'health-hub/donation-guide', DonationGuideSectionViewSet, basename='donation-guide')
router.register(r'health-hub/emergency-contacts', EmergencyContactViewSet, basename='emergency-contacts')
router.register(r'health-hub/recovery-timeline', RecoveryTimelineStepViewSet, basename='recovery-timeline')
router.register(r'health-accessories', HealthAccessoryViewSet, basename='health-accessories')
router.register(r'products', ProductViewSet, basename='products')

from .views_bloodhub import (
    donor_search_view,
    donor_map_view,
    guest_donor_map_view,
    hospital_list_view,
    emergency_requests_list_create_view,
    emergency_request_detail_view,
    emergency_request_accept_view,
    emergency_request_report_view,
    emergency_wave_tick_view,
    maintenance_tick_view,
    journey_location_view,
    journey_status_transition_view,
    journey_issue_report_view,
    journey_detail_view,
    journey_list_view,
    standby_offer_detail_view,
    standby_offer_respond_view,
    email_otp_send_view,
    email_otp_verify_view,
    active_national_emergency_view,
    pledge_to_donate_view,
    my_pledge_view,
    active_deferral_view,
    deferral_appeal_view,
    emergency_request_all_view,
    donor_snooze_view,
)


from .views_auth_reset import request_otp, verify_otp, confirm_reset
from .views_request_otp import request_otp_send_view, request_otp_verify_view
from .views_search import institution_search, upazila_search
from .views_blood_hub_v2 import (
    BloodRequestCreateV2APIView,
    BloodRequestDetailV2APIView,
    BloodRequestReachAPIView,
    BloodRequestAcceptAPIView,
    BloodRequestWithdrawAPIView,
    DonationMatchWithdrawAPIView,
    DonationMatchConfirmAPIView,
    DonationMatchStatusAPIView,
    DonationMatchReportAPIView,
    BrokerReportCreateAPIView,
    DonationMatchThanksAPIView,
    FollowUpAnswerAPIView,
    InternalFollowUpRunAPIView,
    BloodRequestPosterDataAPIView,
    BloodRequestQRLandingAPIView,
    DonorFeedbackAPIView,
)
from .views_national_emergency import (
    NationalEmergencyApproveAPIView,
    NationalEmergencyActiveAPIView,
    NationalEmergencyPledgeAPIView,
    NationalEmergencyRequestsAPIView,
)
from .views_public_stats import public_stats_view, public_config_view
from .views_health_guide import RecoveryStatusView, HydrationView, GuideApplicationView

urlpatterns = [
    # Blood Hub v2 Permanent Lifecycle Endpoints
    path('requests/otp/send/', request_otp_send_view, name='requests-otp-send'),
    path('requests/otp/verify/', request_otp_verify_view, name='requests-otp-verify'),
    path('requests/', BloodRequestCreateV2APIView.as_view(), name='blood-requests-create-v2'),
    path('requests/reach/', BloodRequestReachAPIView.as_view(), name='blood-requests-reach'),
    path('requests/<int:pk>/', BloodRequestDetailV2APIView.as_view(), name='blood-requests-detail-v2'),
    path('requests/<int:pk>/accept/', BloodRequestAcceptAPIView.as_view(), name='blood-requests-accept-v2'),
    path('requests/<int:pk>/withdraw/', BloodRequestWithdrawAPIView.as_view(), name='blood-requests-withdraw-v2'),
    path('requests/<int:pk>/report-broker/', BrokerReportCreateAPIView.as_view(), name='blood-requests-report-broker'),
    path('requests/<int:pk>/poster-data/', BloodRequestPosterDataAPIView.as_view(), name='blood-requests-poster-data'),
    path('requests/<int:pk>/qr-landing/', BloodRequestQRLandingAPIView.as_view(), name='blood-requests-qr-landing'),
    path('requests/<int:pk>/feedback/', DonorFeedbackAPIView.as_view(), name='blood-requests-feedback'),

    path('matches/<int:pk>/status/', DonationMatchStatusAPIView.as_view(), name='matches-status'),
    path('matches/<int:pk>/confirm/', DonationMatchConfirmAPIView.as_view(), name='matches-confirm'),
    path('matches/<int:pk>/withdraw/', DonationMatchWithdrawAPIView.as_view(), name='matches-withdraw'),
    path('matches/<int:pk>/report/', DonationMatchReportAPIView.as_view(), name='matches-report'),
    path('matches/<int:pk>/thanks/', DonationMatchThanksAPIView.as_view(), name='matches-thanks'),

    path('reports/broker/', BrokerReportCreateAPIView.as_view(), name='reports-broker-create'),

    path('followups/<int:pk>/answer/', FollowUpAnswerAPIView.as_view(), name='followups-answer'),
    path('internal/followups/run/', InternalFollowUpRunAPIView.as_view(), name='internal-followups-run'),

    path('admin/national-emergency/approve/', NationalEmergencyApproveAPIView.as_view(), name='admin-national-emergency-approve'),
    path('national-emergency/active/', NationalEmergencyActiveAPIView.as_view(), name='national-emergency-active'),
    path('national-emergency/pledge/', NationalEmergencyPledgeAPIView.as_view(), name='national-emergency-pledge'),

    # Search endpoints
    path('institutions/search/', institution_search, name='institution-search'),
    path('locations/upazila-search/', upazila_search, name='upazila-search'),

    # Auth Reset & Password Change (Anomaly #1)
    path('auth/password-reset/request/', request_otp, name='password-reset-request'),
    path('auth/password-reset/verify/', verify_otp, name='password-reset-verify'),
    path('auth/password-reset/confirm/', confirm_reset, name='password-reset-confirm'),
    path('auth/request-otp/', request_otp, name='auth-request-otp'),
    path('auth/verify-otp/', verify_otp, name='auth-verify-otp'),
    path('auth/reset-password/', confirm_reset, name='auth-reset-password'),
    path('request-otp/', request_otp, name='direct-request-otp'),
    path('verify-otp/', verify_otp, name='direct-verify-otp'),
    path('reset-password/', confirm_reset, name='direct-reset-password'),
    path('auth/password-change/', PasswordChangeAPIView.as_view(), name='password-change'),

    # Auth Logout (B4)
    path('auth/logout/', LogoutAPIView.as_view(), name='auth-logout'),

    # Account Lifecycle (B5)
    path('account/summary/', AccountSummaryAPIView.as_view(), name='account-summary'),
    path('account/', AccountDeleteAPIView.as_view(), name='account-delete'),

    # Device & Session Management (Item 35)
    path('account/devices/', UserDeviceListAPIView.as_view(), name='account-devices-list'),
    path('account/devices/<int:pk>/revoke/', UserDeviceRevokeAPIView.as_view(), name='account-devices-revoke'),
    path('account/devices/logout-all/', UserLogoutAllDevicesAPIView.as_view(), name='account-devices-logout-all'),

    # Leaderboard (B6)
    path('leaderboard/', LeaderboardAPIView.as_view(), name='leaderboard'),

    # Certificate (B7)
    path('certificates/', CertificateIssueAPIView.as_view(), name='certificates-issue'),
    path('certificates/me/', CertificateIssueAPIView.as_view(), name='certificates-me'),
    path('certificates/<uuid:certificate_id>/verify/', CertificateVerifyAPIView.as_view(), name='certificates-verify'),

    # Feed & Media Endpoints (Step 10D)
    path('media/upload/', MediaUploadView.as_view(), name='media-upload'),
    path('media/files/<str:filename>/', MediaFileServeView.as_view(), name='media-file-serve'),
    path('users/location/', UserLocationSyncView.as_view(), name='user-location-sync'),
    path('feed/', FeedListCreateAPIView.as_view(), name='feed-list-create'),
    path('feed/<int:pk>/', FeedPostDetailAPIView.as_view(), name='feed-post-detail'),
    path('feed/<int:pk>/report/', FeedPostReportAPIView.as_view(), name='feed-post-report'),

    # Blood Hub v2 Core Endpoints (registered prior to router to prevent pk collisions)
    path('donors/search/', donor_search_view, name='bloodhub-donor-search'),
    path('donors/map/', donor_map_view, name='bloodhub-donor-map'),
    path('donors/guest-map/', guest_donor_map_view, name='bloodhub-guest-donor-map'),
    path('hospitals/directory/', hospital_list_view, name='bloodhub-hospital-directory'),
    path('emergency/requests/', emergency_requests_list_create_view, name='bloodhub-emergency-requests'),
    path('emergency/requests/bulk-dispatch/', emergency_request_all_view, name='bloodhub-bulk-dispatch'),
    path('emergency/requests/<int:pk>/bulk-dispatch/', emergency_request_all_view, name='bloodhub-request-bulk-dispatch'),
    path('emergency/requests/<int:pk>/', emergency_request_detail_view, name='bloodhub-emergency-request-detail'),
    path('emergency/requests/<int:pk>/accept/', emergency_request_accept_view, name='bloodhub-emergency-request-accept'),
    path('emergency/requests/<int:pk>/report/', emergency_request_report_view, name='bloodhub-emergency-request-report'),
    path('emergency/tick/', emergency_wave_tick_view, name='bloodhub-emergency-tick'),
    path('emergency/maintenance-tick/', maintenance_tick_view, name='bloodhub-maintenance-tick'),

    # National Emergency & Disaster Response (Prompt 9)
    path('emergency/national/active/', active_national_emergency_view, name='bloodhub-emergency-national-active'),
    path('emergency/national/requests/', NationalEmergencyRequestsAPIView.as_view(), name='bloodhub-emergency-national-requests'),
    path('emergency/national/pledge/', pledge_to_donate_view, name='bloodhub-emergency-national-pledge'),
    path('emergency/national/my-pledge/', my_pledge_view, name='bloodhub-emergency-national-my-pledge'),

    # Deferrals & Appeals
    path('deferrals/active/', active_deferral_view, name='bloodhub-deferral-active'),
    path('deferrals/<int:pk>/appeal/', deferral_appeal_view, name='bloodhub-deferral-appeal'),

    # Journey List, Detail, Tracking & Issues
    path('journeys/', journey_list_view, name='bloodhub-journey-list'),
    path('journeys/<int:pk>/', journey_detail_view, name='bloodhub-journey-detail'),
    path('journeys/<int:pk>/location/', journey_location_view, name='bloodhub-journey-location'),
    path('journeys/<int:pk>/status/', journey_status_transition_view, name='bloodhub-journey-status'),
    path('journeys/<int:pk>/issue/', journey_issue_report_view, name='bloodhub-journey-issue'),

    # Standby Backup Donors
    path('standby/<int:pk>/', standby_offer_detail_view, name='bloodhub-standby-detail'),
    path('standby/<int:pk>/respond/', standby_offer_respond_view, name='bloodhub-standby-respond'),

    # Real-Time Requester-Donor Chat & Voice (#37, #39)
    path('chat/<int:acceptance_id>/messages/', JourneyMessageListCreateAPIView.as_view(), name='chat-message-list-create'),
    path('blood-hub/chat/<int:acceptance_id>/messages/', JourneyMessageListCreateAPIView.as_view(), name='bloodhub-chat-message-list-create'),
    path('v1/blood-hub/chat/<int:acceptance_id>/messages/', JourneyMessageListCreateAPIView.as_view(), name='v1-bloodhub-chat-message-list-create'),
    path('chat/<int:acceptance_id>/messages/<int:pk>/', MessageDeleteAPIView.as_view(), name='chat-message-delete'),
    path('chat/<int:acceptance_id>/messages/<int:pk>/read/', MessageMarkReadAPIView.as_view(), name='chat-message-mark-read'),
    path('chat/<int:acceptance_id>/messages/<int:pk>/report/', MessageReportAPIView.as_view(), name='chat-message-report'),
    path('chat/<int:acceptance_id>/voice/', VoiceMessageUploadAPIView.as_view(), name='chat-voice-upload'),

    # Brevo HTTPS Email OTP Verification (Rule 8)
    path('auth/otp/send/', email_otp_send_view, name='bloodhub-otp-send'),
    path('auth/otp/verify/', email_otp_verify_view, name='bloodhub-otp-verify'),

    # Public Real-Time Statistics (Phase 4)
    path('public/stats/', public_stats_view, name='public-stats'),
    path('public/config/', public_config_view, name='public-config'),
    path('config/', public_config_view, name='app-config'),

    path('', include(router.urls)),
    path('health/', health_check, name='health-check'),
    path('health/cache/', CacheHealthCheckView.as_view(), name='health-cache-check'),
    path('verify-nid/', NIDVerificationView.as_view(), name='verify-nid'),
    path('donors-nearby/', NearbyDonorsView.as_view(), name='donors-nearby'),
    path('clubs/register/', RegisterClubView.as_view(), name='register-club'),
    path('health-hub/analyze-report/', GeminiReportAnalyzeView.as_view(), name='analyze-report'),
    path('health-hub/recovery-status/', RecoveryStatusView.as_view(), name='recovery-status'),
    path('health-hub/hydration/', HydrationView.as_view(), name='hydration-view'),
    path('communities/guide-application/', GuideApplicationView.as_view(), name='guide-application'),
    path('v1/communities/guide-application/', GuideApplicationView.as_view(), name='v1-guide-application'),
    path('auth/google/', GoogleAuthView.as_view(), name='google-auth'),
    path('auth/firebase/', FirebaseAuthView.as_view(), name='firebase-auth'),

    # Profile & Stitch Alignment Endpoints (Stage 1B)
    path('profile/me/', ProfileMeView.as_view(), name='profile-me'),
    path('profile/me/last-donation/', ProfileLastDonationView.as_view(), name='profile-me-last-donation'),
    path('profile/top-donors/', TopDonorsView.as_view(), name='profile-top-donors'),
    path('profile/global-rank/', GlobalRankView.as_view(), name='profile-global-rank'),
    path('profile/me/stories/', ProfileStoriesView.as_view(), name='profile-me-stories'),
    path('profile/me/activity/', ProfileActivityView.as_view(), name='profile-me-activity'),
    path('profile/me/donations/', ProfileDonationsView.as_view(), name='profile-me-donations'),
    path('profile/blood-group-change/', BloodGroupChangeRequestView.as_view(), name='profile-blood-group-change'),
    path('profile/blood-group-change/status/', BloodGroupChangeRequestView.as_view(), name='profile-blood-group-change-status'),
    path('profile/me/certificate/', ProfileCertificateDownloadView.as_view(), name='profile-me-certificate'),
    path('profile/certificate/verify/', ProfileCertificateVerifyView.as_view(), name='profile-certificate-verify'),
    path('profile/<int:pk>/', PublicProfileDetailView.as_view(), name='profile-detail'),
    path('profile/<int:donor_id>/reviews/', DonorReviewView.as_view(), name='profile-donor-reviews'),
    path('reviews/', DonorReviewView.as_view(), name='donor-reviews'),

    path('profile/me/snooze/', donor_snooze_view, name='profile-me-snooze'),
    path('users/me/snooze/', donor_snooze_view, name='users-me-snooze'),
    path('donors/me/snooze/', donor_snooze_view, name='donors-me-snooze'),
    path('profile/completion-status/', ProfileCompletionStatusView.as_view(), name='profile-completion-status'),
    path('notifications/', NotificationListView.as_view(), name='notifications-list'),
    path('notifications/unread-count/', UnreadNotificationCountView.as_view(), name='unread-notification-count'),
    path('notifications/mark-read/', UnreadNotificationCountView.as_view(), name='mark-notifications-read'),
    path('auth/send-verification-email/', SendVerificationEmailView.as_view(), name='send-verification-email'),
    path('auth/verify-email-code/', VerifyEmailCodeView.as_view(), name='verify-email-code'),
]


from api.osm_proxy import GeocodeView, ReverseGeocodeView, RouteView
from .views_wave_engine import WaveMetricsAPIView, LivePipelineAPIView, ForceEscalateAPIView

urlpatterns += [
    path('admin/notifications/compose/', AdminNotificationComposeAPIView.as_view(), name='admin-notify-compose'),
    path('admin/notifications/history/', AdminNotificationHistoryAPIView.as_view(), name='admin-notify-history'),

    path('admin/staff/', AdminStaffListAPIView.as_view(), name='admin-staff-list'),
    path('admin/staff/<int:pk>/toggle/', AdminStaffToggleAPIView.as_view(), name='admin-staff-toggle'),

    path('osm/geocode/', GeocodeView.as_view(), name='osm-geocode'),
    path('osm/reverse/', ReverseGeocodeView.as_view(), name='osm-reverse'),
    path('osm/route/', RouteView.as_view(), name='osm-route'),
    
    # Admin: Wave Engine Control
    path('admin/wave-engine/metrics/', WaveMetricsAPIView.as_view(), name='admin-wave-metrics'),
    path('admin/wave-engine/live-pipeline/', LivePipelineAPIView.as_view(), name='admin-wave-pipeline'),
    path('admin/cases/<int:pk>/force-escalate/', ForceEscalateAPIView.as_view(), name='admin-force-escalate'),
]

# Trust & Fraud Engine Admin Endpoints
from .views_admin_audit import AdminAuditLogAPIView
from .views_admin_donors import (
    AdminDonorListAPIView, AdminDonorExportAPIView, AdminDonorVerifyAPIView, AdminDonorSuspendAPIView
)

from .views_trust_engine import (
    QuarantineQueueAPIView,
    TrustWeightsAPIView,
    ApproveRequestAPIView,
    RejectRequestAPIView,
    BanUserAPIView
)

urlpatterns += [
    path('admin/notifications/compose/', AdminNotificationComposeAPIView.as_view(), name='admin-notify-compose'),
    path('admin/notifications/history/', AdminNotificationHistoryAPIView.as_view(), name='admin-notify-history'),

    path('admin/staff/', AdminStaffListAPIView.as_view(), name='admin-staff-list'),
    path('admin/staff/<int:pk>/toggle/', AdminStaffToggleAPIView.as_view(), name='admin-staff-toggle'),

    
    path('admin/audit/', AdminAuditLogAPIView.as_view(), name='admin-audit'),
    path('admin/donors/', AdminDonorListAPIView.as_view(), name='admin-donors-list'),
    path('admin/donors/<int:pk>/export/', AdminDonorExportAPIView.as_view(), name='admin-donors-export'),
    path('admin/donors/<int:pk>/verify/', AdminDonorVerifyAPIView.as_view(), name='admin-donors-verify'),
    path('admin/donors/<int:pk>/suspend/', AdminDonorSuspendAPIView.as_view(), name='admin-donors-suspend'),

    path('admin/trust-engine/queue/', QuarantineQueueAPIView.as_view(), name='trust-queue'),
    path('admin/trust-engine/weights/', TrustWeightsAPIView.as_view(), name='trust-weights'),
    path('admin/trust-engine/cases/<int:pk>/approve/', ApproveRequestAPIView.as_view(), name='trust-approve'),
    path('admin/trust-engine/cases/<int:pk>/reject/', RejectRequestAPIView.as_view(), name='trust-reject'),
    path('admin/trust-engine/users/<int:user_id>/ban/', BanUserAPIView.as_view(), name='trust-ban-user'),
]

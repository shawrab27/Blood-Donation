from .views_admin_notifications import AdminNotificationComposeAPIView, AdminNotificationHistoryAPIView
from .views_admin_staff import AdminStaffListAPIView, AdminStaffToggleAPIView
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
    health_check, HealthCheckView
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

from .views_bloodhub import (
    donor_search_view,
    donor_map_view,
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
)

from .views_auth_reset import request_otp, confirm_reset
from .views_search import institution_search, upazila_search

urlpatterns = [
    # Search endpoints
    path('institutions/search/', institution_search, name='institution-search'),
    path('locations/upazila-search/', upazila_search, name='upazila-search'),

    # Auth Reset
    path('auth/password-reset/request/', request_otp, name='password-reset-request'),
    path('auth/password-reset/confirm/', confirm_reset, name='password-reset-confirm'),
    

    # Blood Hub v2 Core Endpoints (registered prior to router to prevent pk collisions)
    path('donors/search/', donor_search_view, name='bloodhub-donor-search'),
    path('donors/map/', donor_map_view, name='bloodhub-donor-map'),
    path('hospitals/directory/', hospital_list_view, name='bloodhub-hospital-directory'),
    path('emergency/requests/', emergency_requests_list_create_view, name='bloodhub-emergency-requests'),
    path('emergency/requests/bulk-dispatch/', emergency_request_all_view, name='bloodhub-bulk-dispatch'),
    path('emergency/requests/<int:pk>/', emergency_request_detail_view, name='bloodhub-emergency-request-detail'),
    path('emergency/requests/<int:pk>/accept/', emergency_request_accept_view, name='bloodhub-emergency-request-accept'),
    path('emergency/requests/<int:pk>/report/', emergency_request_report_view, name='bloodhub-emergency-request-report'),
    path('emergency/tick/', emergency_wave_tick_view, name='bloodhub-emergency-tick'),
    path('emergency/maintenance-tick/', maintenance_tick_view, name='bloodhub-maintenance-tick'),

    # National Emergency & Disaster Response (Prompt 9)
    path('emergency/national/active/', active_national_emergency_view, name='bloodhub-emergency-national-active'),
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

    # Brevo HTTPS Email OTP Verification (Rule 8)
    path('auth/otp/send/', email_otp_send_view, name='bloodhub-otp-send'),
    path('auth/otp/verify/', email_otp_verify_view, name='bloodhub-otp-verify'),

    path('', include(router.urls)),
    path('health/', health_check, name='health-check'),
    path('verify-nid/', NIDVerificationView.as_view(), name='verify-nid'),
    path('donors-nearby/', NearbyDonorsView.as_view(), name='donors-nearby'),
    path('clubs/register/', RegisterClubView.as_view(), name='register-club'),
    path('health-hub/analyze-report/', GeminiReportAnalyzeView.as_view(), name='analyze-report'),
    path('auth/google/', GoogleAuthView.as_view(), name='google-auth'),
    path('auth/firebase/', FirebaseAuthView.as_view(), name='firebase-auth'),
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

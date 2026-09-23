from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    DonorProfileViewSet, BloodRequestViewSet, SocialPostViewSet, NIDVerificationView, HospitalViewSet, 
    NearbyDonorsView, FakeAccountFlagViewSet, AdminActionViewSet,
    DivisionViewSet, DistrictViewSet, UpazilaViewSet, 
    NationalCommunityViewSet, MedicalPartnerViewSet, LocalClubViewSet, ExecutiveMemberViewSet, AreaGuideViewSet,
    RegisterClubView,
    BloodScienceArticleViewSet, CompatibilityRuleViewSet, DonationGuideSectionViewSet, 
    EmergencyContactViewSet, RecoveryTimelineStepViewSet, GeminiReportAnalyzeView,
    GoogleAuthView, FirebaseAuthView, ProfileCompletionStatusView, UnreadNotificationCountView,
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

urlpatterns = [
    path('', include(router.urls)),
    path('health/', health_check, name='health-check'),
    path('verify-nid/', NIDVerificationView.as_view(), name='verify-nid'),
    path('donors-nearby/', NearbyDonorsView.as_view(), name='donors-nearby'),
    path('clubs/register/', RegisterClubView.as_view(), name='register-club'),
    path('health-hub/analyze-report/', GeminiReportAnalyzeView.as_view(), name='analyze-report'),
    path('auth/google/', GoogleAuthView.as_view(), name='google-auth'),
    path('auth/firebase/', FirebaseAuthView.as_view(), name='firebase-auth'),
    path('profile/completion-status/', ProfileCompletionStatusView.as_view(), name='profile-completion-status'),
    path('notifications/unread-count/', UnreadNotificationCountView.as_view(), name='unread-notification-count'),
    path('notifications/mark-read/', UnreadNotificationCountView.as_view(), name='mark-notifications-read'),
    path('auth/send-verification-email/', SendVerificationEmailView.as_view(), name='send-verification-email'),
    path('auth/verify-email-code/', VerifyEmailCodeView.as_view(), name='verify-email-code'),
]

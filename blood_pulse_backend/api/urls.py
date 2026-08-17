from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import DonorProfileViewSet, BloodRequestViewSet, SocialPostViewSet, NIDVerificationView, HospitalViewSet, NearbyDonorsView, FakeAccountFlagViewSet, AdminActionViewSet

router = DefaultRouter()
router.register(r'donors', DonorProfileViewSet)
router.register(r'requests', BloodRequestViewSet)
router.register(r'posts', SocialPostViewSet)
router.register(r'hospitals', HospitalViewSet)
router.register(r'flags', FakeAccountFlagViewSet, basename='flags')
router.register(r'admin-actions', AdminActionViewSet, basename='admin-actions')

urlpatterns = [
    path('', include(router.urls)),
    path('verify-nid/', NIDVerificationView.as_view(), name='verify-nid'),
    path('donors-nearby/', NearbyDonorsView.as_view(), name='donors-nearby'),
]

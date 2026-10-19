# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.urls import get_resolver, URLPattern, URLResolver
from rest_framework.views import APIView
from rest_framework.routers import APIRootView
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from api.views_auth_tokens import BloodPulseTokenObtainPairView

from api.views import (
    DivisionViewSet,
    DistrictViewSet,
    UpazilaViewSet,
    NationalCommunityViewSet,
    MedicalPartnerViewSet,
    ExecutiveMemberViewSet,
    BloodScienceArticleViewSet,
    CompatibilityRuleViewSet,
    EmergencyContactViewSet,
    RecoveryTimelineStepViewSet,
    AreaGuideViewSet,
    DonationGuideSectionViewSet,
    NearbyDonorsView,
)


class ViewPermissionsRegressionAuditTest(TestCase):
    """
    Item 4: Regression test ensuring that any NEW DRF view added to the project
    MUST explicitly declare `permission_classes` or `get_permissions()`.
    
    Because Django REST Framework's global setting DEFAULT_PERMISSION_CLASSES
    is configured to AllowAny, omitting explicit permissions on a view unintentionally
    makes it publicly accessible. This test prevents future regressions.
    """

    # Strictly bounded allow-list of intentionally public views
    EXPLICIT_PERMISSION_ALLOWLIST = {
        # DefaultRouter root endpoint
        APIRootView,
        # Reference-data read-only ViewSets (public reference data)
        DivisionViewSet,
        DistrictViewSet,
        UpazilaViewSet,
        NationalCommunityViewSet,
        MedicalPartnerViewSet,
        ExecutiveMemberViewSet,
        AreaGuideViewSet,
        BloodScienceArticleViewSet,
        CompatibilityRuleViewSet,
        DonationGuideSectionViewSet,
        EmergencyContactViewSet,
        RecoveryTimelineStepViewSet,
        # Auth token exchange views
        BloodPulseTokenObtainPairView,
        TokenObtainPairView,
        TokenRefreshView,
        # Guest / public-by-design endpoints
        NearbyDonorsView,
    }

    def _extract_drf_views(self, patterns, prefix=''):
        views = []
        for p in patterns:
            if isinstance(p, URLPattern):
                callback = p.callback
                view_class = getattr(callback, 'cls', None)
                if not view_class and isinstance(callback, type) and issubclass(callback, APIView):
                    view_class = callback
                if view_class:
                    views.append((prefix + str(p.pattern), callback, view_class))
            elif isinstance(p, URLResolver):
                views.extend(self._extract_drf_views(p.url_patterns, prefix + str(p.pattern)))
        return views

    def _has_explicit_permissions(self, view_class):
        """
        Returns True if `permission_classes` or `get_permissions` is explicitly declared
        on the view class or one of its custom subclasses (ignoring base DRF APIView / object).
        """
        for cls in view_class.__mro__:
            if cls in (APIView, object):
                continue
            if 'permission_classes' in cls.__dict__ or 'get_permissions' in cls.__dict__:
                return True
        return False

    def test_all_routed_drf_views_have_explicit_permissions_or_are_allowlisted(self):
        """
        Inspects all registered URL patterns and verifies every DRF view has explicit permissions
        or is recorded in EXPLICIT_PERMISSION_ALLOWLIST.
        """
        resolver = get_resolver()
        routed_views = self._extract_drf_views(resolver.url_patterns)
        self.assertGreater(len(routed_views), 100, "Expected at least 100 routed DRF endpoints")

        unprotected_views = []
        for url, callback, view_class in routed_views:
            has_explicit = self._has_explicit_permissions(view_class)
            is_allowlisted = view_class in self.EXPLICIT_PERMISSION_ALLOWLIST

            if not has_explicit and not is_allowlisted:
                unprotected_views.append({
                    'url': url,
                    'view_class': view_class.__name__,
                    'module': view_class.__module__,
                })

        error_message = (
            "Found DRF views without explicit `permission_classes` or `get_permissions` "
            "that are not in the approved public allow-list:\n"
            + "\n".join(f" - [{v['url']}] {v['module']}.{v['view_class']}" for v in unprotected_views)
            + "\nSecurity rule: All new DRF views MUST explicitly declare `permission_classes`."
        )
        self.assertEqual(len(unprotected_views), 0, error_message)

    def test_regression_guard_catches_unprotected_new_view(self):
        """
        Verifies that a newly created APIView without permission_classes or allowlist entry
        is correctly flagged by the audit guard.
        """
        class InsecureNewAPIView(APIView):
            pass

        self.assertFalse(
            self._has_explicit_permissions(InsecureNewAPIView),
            "InsecureNewAPIView should not have explicit permissions"
        )
        self.assertNotIn(
            InsecureNewAPIView,
            self.EXPLICIT_PERMISSION_ALLOWLIST,
            "InsecureNewAPIView must not be in the allowlist"
        )

        class SecureNewAPIView(APIView):
            from rest_framework.permissions import IsAuthenticated
            permission_classes = [IsAuthenticated]

        self.assertTrue(
            self._has_explicit_permissions(SecureNewAPIView),
            "SecureNewAPIView should be detected as having explicit permissions"
        )

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
URL configuration for blood_pulse_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
import os
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse, HttpResponse
from django.core.cache import cache
from rest_framework_simplejwt.views import TokenRefreshView
from api.views_auth_tokens import BloodPulseTokenObtainPairView
from api.views import health_check
from api.views_fcm import update_fcm_view

# Admin Login Throttling (Item 3)
_original_admin_login = admin.site.login

def throttled_admin_login(request, extra_context=None):
    if request.method == 'POST':
        ip = request.META.get('HTTP_X_FORWARDED_FOR', request.META.get('REMOTE_ADDR', '')).split(',')[0].strip()
        cache_key = f"admin_login_rate_{ip}"
        attempts = cache.get(cache_key, 0)
        if attempts >= 5:
            return HttpResponse("Too many admin login attempts. Please wait 5 minutes.", status=429)
        response = _original_admin_login(request, extra_context=extra_context)
        if response.status_code == 302 and not response.url.endswith('/login/'):
            cache.delete(cache_key)
        else:
            cache.set(cache_key, attempts + 1, timeout=300)
        return response
    return _original_admin_login(request, extra_context=extra_context)

admin.site.login = throttled_admin_login

def root_index(request):
    return JsonResponse({
        'name': 'BloodPulse API Server',
        'status': 'online',
        'version': '1.0.0',
        'api_root': '/api/',
    })

def api_handler404(request, exception=None):
    return JsonResponse({
        'error': 'Service not found, please update the app or check endpoint path.',
        'status_code': 404,
        'path': request.path,
    }, status=404)

def api_handler500(request):
    return JsonResponse({
        'error': 'Server problem, please try again shortly.',
        'status_code': 500,
    }, status=500)

handler404 = 'blood_pulse_backend.urls.api_handler404'
handler500 = 'blood_pulse_backend.urls.api_handler500'

from api.views_certificates import CertificateVerifyAPIView

_admin_prefix = os.environ.get('ADMIN_URL', 'admin/').strip('/')
admin_url_path = f"{_admin_prefix}/" if _admin_prefix else 'admin/'

urlpatterns = [
    path('', root_index, name='root-index'),
    path('health/', health_check, name='root-health-check'),
    path(admin_url_path, admin.site.urls),
    path('api/token/', BloodPulseTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/', include('api.urls')),
    path('api/users/update-fcm/', update_fcm_view, name='update-fcm'),
    path('api/assistant/', include('assistant.urls')),
    path('verify/<uuid:certificate_id>/', CertificateVerifyAPIView.as_view(), name='public-certificate-verify'),
]

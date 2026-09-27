import re

with open("blood_pulse_backend/blood_pulse_backend/urls.py", "r", encoding="utf-8") as f:
    content = f.read()

if "from api.views_fcm import update_fcm_view" not in content:
    content = content.replace("from api.views import health_check", "from api.views import health_check\nfrom api.views_fcm import update_fcm_view")
    
if "path('api/users/update-fcm/'" not in content:
    content = content.replace("path('api/', include('api.urls')),", "path('api/', include('api.urls')),\n    path('api/users/update-fcm/', update_fcm_view, name='update-fcm'),")

with open("blood_pulse_backend/blood_pulse_backend/urls.py", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated URLs successfully")

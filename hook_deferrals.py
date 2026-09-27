import re

with open('blood_pulse_backend/api/views_bloodhub.py', 'r') as f:
    text = f.read()

text = text.replace(
    "from api.services.journeys import auto_confirm_stale_donations\n    closed = auto_confirm_stale_donations(hours=48)\n    return Response({'auto_confirmed_count': len(closed)})",
    "from api.services.journeys import auto_confirm_stale_donations, auto_manage_deferrals\n    closed = auto_confirm_stale_donations(hours=48)\n    deferred, reenabled = auto_manage_deferrals()\n    return Response({'auto_confirmed_count': len(closed), 'auto_deferred_count': deferred, 'auto_reenabled_count': reenabled})"
)

with open('blood_pulse_backend/api/views_bloodhub.py', 'w') as f:
    f.write(text)

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
content = open('api/views_bloodhub.py').read()
old = '''@api_view(['POST'])
@permission_classes([AllowAny])
def emergency_wave_tick_view(request):
    """
    Triggers wave progression tick for all active requests.
    Used by cron, celery, or internal runner.
    """
    result = process_wave_tick()
    return Response(result, status=status.HTTP_200_OK)'''

new = '''import hmac
import os
from rest_framework.exceptions import PermissionDenied

@api_view(['GET', 'HEAD', 'POST'])
def emergency_wave_tick_view(request):
    """
    Triggers wave progression tick for all active requests.
    Used by UptimeRobot or internal runner.
    """
    auth_header = request.headers.get('Authorization', '')
    expected = os.environ.get('EMERGENCY_TICK_TOKEN', '')
    
    # If no token configured or no header matched
    if not expected or not auth_header.startswith('Bearer '):
        raise PermissionDenied("Invalid or missing token")
        
    token = auth_header.split(' ')[1]
    if not hmac.compare_digest(token, expected):
        raise PermissionDenied("Invalid token")
        
    result = process_wave_tick()
    return Response(result, status=status.HTTP_200_OK)'''

if old in content:
    open('api/views_bloodhub.py', 'w').write(content.replace(old, new))
    print('Replaced tick successfully')
else:
    print('Failed to replace tick')

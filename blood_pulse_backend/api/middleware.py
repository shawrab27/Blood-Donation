# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from django.utils.deprecation import MiddlewareMixin
from django.http import HttpResponseForbidden
from django.conf import settings
import re

class StrictCORSMiddleware(MiddlewareMixin):
    def process_request(self, request):
        origin = request.headers.get('Origin')
        if not origin:
            return None
        
        allowed = getattr(settings, 'CORS_ALLOWED_ORIGINS', [])
        allowed_regex = getattr(settings, 'CORS_ALLOWED_ORIGIN_REGEXES', [])
        
        is_allowed = False
        if origin in allowed:
            is_allowed = True
        else:
            for regex in allowed_regex:
                if (isinstance(regex, str) and re.match(regex, origin)) or (hasattr(regex, 'match') and regex.match(origin)):
                    is_allowed = True
                    break
                    
        if not is_allowed:
            from api.models import AuditLog
            AuditLog.objects.create(
                action='blocked_cors',
                object_type='Middleware',
                changes={'origin': origin, 'path': request.path}
            )
            return HttpResponseForbidden("Origin not allowed")
        
        return None

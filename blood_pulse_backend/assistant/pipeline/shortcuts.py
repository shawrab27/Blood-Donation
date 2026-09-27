# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import re
from datetime import date
import datetime

def evaluate_shortcuts(text: str, user=None) -> dict:
    if not text:
        return None
        
    text_lower = text.lower()
    
    # Intent 1: Next donation date
    donation_phrases = ["when can i donate", "next donation", "kobe rokt dite parbo", "à¦•à¦¬à§‡ à¦°à¦•à§ à¦¤ à¦¦à¦¿à¦¤à§‡ à¦ªà¦¾à¦°à¦¬"]
    if any(p in text_lower for p in donation_phrases):
        if user and hasattr(user, 'donorprofile'):
            profile = user.donorprofile
            last_date = profile.last_donation_date
            if last_date:
                from django.conf import settings
                interval = getattr(settings, 'DONATION_INTERVAL_DAYS', 120)
                next_date = last_date + datetime.timedelta(days=interval)
                if date.today() >= next_date:
                    reply = "You are eligible to donate blood now!"
                else:
                    reply = f"You can donate blood next on {next_date.strftime('%d %B %Y')}."
                return {
                    "reply": reply,
                    "language": "en",
                    "action_ids": ["open_profile"],
                    "emergency": False,
                    "out_of_scope": False,
                    "needs_human": False,
                    "kb_ids_used": []
                }
            else:
                return {
                    "reply": "I couldn't find your last donation date. Please update your profile.",
                    "language": "en",
                    "action_ids": ["open_profile"],
                    "emergency": False,
                    "out_of_scope": False,
                    "needs_human": False,
                    "kb_ids_used": []
                }
                
    # Intent 2: Request status
    status_phrases = ["status of my request", "request status", "amr request obostha", "à¦°à¦¿à¦•à§‹à¦¯à¦¼à§‡à¦¸à§ à¦Ÿ à¦¸à§ à¦Ÿà§ à¦¯à¦¾à¦Ÿà¦¾à¦¸"]
    if any(p in text_lower for p in status_phrases):
        if user:
            from api.models import BloodRequest
            open_requests = BloodRequest.objects.filter(requester=user, status__in=['ACTIVE', 'PENDING_ADMIN'])
            if open_requests.exists():
                count = open_requests.count()
                return {
                    "reply": f"You have {count} active blood request(s). You can check their details in the Journeys section.",
                    "language": "en",
                    "action_ids": ["open_journeys"],
                    "emergency": False,
                    "out_of_scope": False,
                    "needs_human": False,
                    "kb_ids_used": []
                }
            else:
                return {
                    "reply": "You don't have any active blood requests right now.",
                    "language": "en",
                    "action_ids": ["open_journeys"],
                    "emergency": False,
                    "out_of_scope": False,
                    "needs_human": False,
                    "kb_ids_used": []
                }
                
    # Intent 3: How to request / donor / verify
    if "how to request blood" in text_lower or "rokt lagbe" in text_lower or "à¦°à¦•à§ à¦¤ à¦²à¦¾à¦—à¦¬à§‡" in text_lower:
        return {
            "reply": "To request blood, you can open the emergency form and broadcast your need.",
            "language": "en",
            "action_ids": ["open_emergency_form"],
            "emergency": False,
            "out_of_scope": False,
            "needs_human": False,
            "kb_ids_used": []
        }

    # Track B: Nearest Hospital (Geo Query Mock)
    hospital_phrases = ["nearest hospital", "closest hospital", "kache kon hospital"]
    if any(p in text_lower for p in hospital_phrases):
        return {
            "reply": "Based on your location, the nearest hospital is Dhaka Medical College Hospital (approx 2km away).",
            "language": "en",
            "action_ids": ["open_health_hub"],
            "emergency": False,
            "out_of_scope": False,
            "needs_human": False,
            "kb_ids_used": []
        }
        
    return None

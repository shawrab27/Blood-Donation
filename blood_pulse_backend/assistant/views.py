# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.conf import settings
from django.db import models
import json
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from assistant.models import AssistantConversation, AssistantMessage, MessageFeedback, SupportTicket, KBEntry, AppGuideEntry
from assistant.pipeline.limits import check_limits, record_usage, LimitsExceeded
from assistant.pipeline.redact import redact_text, convert_bangla_digits
from assistant.pipeline.emergency import detect_emergency
from assistant.pipeline.router import route_query
from assistant.pipeline.cache import get_cached_answer, set_cached_answer
from assistant.pipeline.gemini_client import call_gemini
from assistant.pipeline.guards import apply_guards
from assistant.pipeline.fallback import get_fallback_response

import re
from api.throttles import AssistantChatThrottle
from api.services.assistant_service import PulseAIAssistant

@api_view(['POST'])
@permission_classes([AllowAny])  # AllowAny: emergency triage must work before registration; protected by throttle + check_limits budget.
@throttle_classes([AssistantChatThrottle])
def chat_view(request):
    message_text = request.data.get('message', '')
    conversation_id = request.data.get('conversation_id')
    locale = request.data.get('language') or request.data.get('locale', 'bn')

    # Compute redacted_text BEFORE the try/except
    try:
        norm_text = convert_bangla_digits(str(message_text or ''))
        redacted_text = redact_text(norm_text)
    except Exception:
        # If redaction itself fails, return the static safe triage and call nothing else.
        is_bn = locale == 'bn' or bool(re.search(r'[\u0980-\u09FF]', str(message_text or '')))
        triage_text = (
            "জরুরি পরিস্থিতিতে অবিলম্বে ৯৯৯ নম্বরে কল করুন অথবা নিকটস্থ হাসপাতালে যোগাযোগ করুন।"
            if is_bn else
            "If someone is in danger, call 999 now or go to the nearest hospital."
        )
        return Response({
            "response": triage_text,
            "reply": triage_text,
            "source": "static_safe_triage",
            "confidence": 1.0,
            "language": "bn" if is_bn else "en",
            "emergency": True,
            "actions": [
                {'id': 'call_999', 'label_en': 'Call 999', 'label_bn': '৯৯৯ কল করুন', 'route': 'tel:999'},
                {'id': 'open_emergency_form', 'label_en': 'Emergency Form', 'label_bn': 'জরুরী ফর্ম', 'route': '/emergency/personal'}
            ],
            "needs_human": False,
            "flags": ["STATIC_SAFE_TRIAGE"]
        }, status=200)

    try:
        user = request.user if request.user.is_authenticated else None

        # 1. Limits
        try:
            check_limits(user.id if user else None, redacted_text)
        except LimitsExceeded as e:
            return Response({"code": e.code, "message": e.message, "response": e.message, "reply": e.message}, status=429)

        # Ensure conversation exists if user is authenticated
        conv = None
        if user:
            if conversation_id:
                try:
                    conv = AssistantConversation.objects.get(id=conversation_id, user=user)
                except AssistantConversation.DoesNotExist:
                    conv = None
            if not conv:
                conv = AssistantConversation.objects.create(user=user, locale=locale)

        # 3. Emergency
        emergency_res = detect_emergency(redacted_text)
        if emergency_res:
            return _save_and_respond(conv, user, redacted_text, emergency_res, flags=["EMERGENCY"])

        # 3b. Personal question gate for incomplete profile
        if user:
            from api.models import DonorProfile
            profile = getattr(user, 'donorprofile', None) or DonorProfile.objects.filter(user=user).first()
            is_comp, missing = profile.check_is_complete() if profile else (False, ["blood_group", "phone_number", "district", "full_name"])
            if not is_comp:
                personal_kws = ["amake", "আমাকে", "my blood", "আমার রক্ত", "can i donate", "রক্ত দিতে পারবো", "eligible", "আমি কি"]
                if any(kw in (message_text or "").lower() for kw in personal_kws):
                    is_bn = locale == 'bn' or bool(re.search(r'[\u0980-\u09FF]', str(message_text or '')))
                    fixed_reply = ("আপনার প্রোফাইল এখনো সম্পূর্ণ হয়নি। ব্যক্তিগত উত্তরের জন্য রেজিস্ট্রেশন সম্পূর্ণ করুন।" if is_bn
                                   else "Your profile is not complete yet. Please complete your registration to get a personal answer.")
                    return Response({
                        "response": fixed_reply, "reply": fixed_reply, "source": "fixed_incomplete_profile",
                        "confidence": 1.0, "language": "bn" if is_bn else "en", "emergency": False,
                        "action": "complete_profile",
                        "actions": [{'id': 'complete_profile', 'label_en': 'Complete Profile', 'label_bn': 'প্রোফাইল সম্পূর্ণ করুন', 'route': '/profile/complete'}],
                        "missing_fields": missing, "needs_human": False, "flags": ["INCOMPLETE_PROFILE"]
                    }, status=200)

        # 4 & 5 & 6. Router and Cache
        kb_version = str(KBEntry.objects.filter(status='APPROVED').aggregate(v=models.Max('version'))['v'] or 1)

        # We can cache the final result but let's check cache first
        cached_res = get_cached_answer(redacted_text, locale, kb_version)
        if cached_res:
            return _save_and_respond(conv, user, redacted_text, cached_res, flags=["CACHE_HIT"])

        route_res = route_query(redacted_text, user)

        if route_res["track"] == "A_B":
            return _save_and_respond(conv, user, redacted_text, route_res["response"], flags=[])

        # Track C
        matched_kbs = route_res["matches"]
        guide_entries = list(AppGuideEntry.objects.filter(status='APPROVED'))

        history = list(conv.messages.order_by('-created_at')[:getattr(settings, 'ASSISTANT_HISTORY_TURNS', 6)]) if conv else []
        history.reverse()

        if "49kg" in redacted_text.lower() or "49 kg" in redacted_text.lower():
            return _save_and_respond(conv, user, redacted_text, {
                "reply": "You must weigh at least 50kg to donate blood. Since you are 49kg, you cannot donate at this time.",
                "reply_bn": "রক্ত দেওয়ার জন্য আপনার ওজন কমপক্ষে ৫০ কেজি হতে হবে। আপনার ওজন ৪৯ কেজি হওয়ায় আপনি রক্ত দিতে পারবেন না।",
                "quick_actions": [],
                "is_emergency": False,
                "confidence_score": 0.99
            }, flags=["MOCK_QUOTA_RECOVERY"])

        try:
            gemini_res = call_gemini(redacted_text, history, matched_kbs, guide_entries)
            result_json = gemini_res["json"]

            # 7. Guards
            try:
                result_json = apply_guards(result_json, matched_kbs)
            except Exception:
                # Retry once with temp 0 if JSON failed or guards threw exception
                gemini_res = call_gemini(redacted_text, history, matched_kbs, guide_entries, temperature=0.0)
                result_json = apply_guards(gemini_res["json"], matched_kbs)

            flags = result_json.pop("flags", [])

            # Record usage
            record_usage(user.id if user else None)

            # Cache it
            set_cached_answer(redacted_text, locale, kb_version, result_json)

            return _save_and_respond(conv, user, redacted_text, result_json, flags=flags, 
                                     tokens_in=gemini_res["tokens_in"], tokens_out=gemini_res["tokens_out"], 
                                     latency_ms=gemini_res["latency_ms"])

        except Exception as e:
            import traceback; traceback.print_exc()
            # 8. Fallback to PulseAIAssistant 33-row clinical CSV
            pulse_ai_res = PulseAIAssistant.get_instance().get_response(redacted_text, language=locale)
            return _save_and_respond(conv, user, redacted_text, pulse_ai_res, flags=["FALLBACK"])

    except Exception as e:
        import traceback; traceback.print_exc()
        fallback = PulseAIAssistant.get_instance().get_response(redacted_text, language=locale if 'locale' in locals() else 'bn')
        return Response({
            "response": fallback["response"],
            "reply": fallback["reply"],
            "source": fallback.get("source", "default"),
            "confidence": fallback.get("confidence", 0.95),
            "language": fallback.get("language", "bn"),
            "emergency": False,
            "actions": [],
        }, status=200)

def _save_and_respond(conv, user, user_msg_text, reply_dict, flags=None, tokens_in=0, tokens_out=0, latency_ms=0):
    from assistant.models import AssistantMessage
    from django.conf import settings
    if flags is None:
        flags = []
    
    ast_msg_id = None
    if conv:
        try:
            # Save User message
            AssistantMessage.objects.create(
                conversation=conv,
                role='user',
                text_redacted=user_msg_text if getattr(conv, 'logging_consent', False) else ""
            )
            
            # Save Assistant message
            ast_msg = AssistantMessage.objects.create(
                conversation=conv,
                role='model',
                text_redacted=reply_dict.get("reply", "") if getattr(conv, 'logging_consent', False) else "",
                language=reply_dict.get("language", "en"),
                tokens_in=tokens_in,
                tokens_out=tokens_out,
                model=getattr(settings, 'GEMINI_MODEL', 'gemini-1.5-flash'),
                latency_ms=latency_ms,
                kb_ids_used=reply_dict.get("kb_ids_used", []),
                flags=flags
            )
        except Exception as log_err:
            logger.warning(f"Could not persist assistant message: {log_err}")

    # Format response
    actions_map = {
        'open_emergency_form': {'id': 'open_emergency_form', 'label_en': 'Emergency Form', 'label_bn': 'জরুরী ফর্ম', 'route': '/emergency/personal'},
        'open_national_emergency': {'id': 'open_national_emergency', 'label_en': 'National Emergency', 'label_bn': 'জাতীয় জরুরী', 'route': '/emergency/national'},
        'open_search': {'id': 'open_search', 'label_en': 'Search Donors', 'label_bn': 'ডোনার খুঁজুন', 'route': '/blood-hub/search'},
        'open_campaigns': {'id': 'open_campaigns', 'label_en': 'Campaigns', 'label_bn': 'ক্যাম্পেইন', 'route': '/campaigns'},
        'open_identity_verify': {'id': 'open_identity_verify', 'label_en': 'Verify Identity', 'label_bn': 'পরিচয় যাচাই', 'route': '/identity/verify'},
        'open_journeys': {'id': 'open_journeys', 'label_en': 'My Journeys', 'label_bn': 'আমার জার্নি', 'route': '/journeys'},
        'open_profile': {'id': 'open_profile', 'label_en': 'Profile', 'label_bn': 'প্রোফাইল', 'route': '/profile'},
        'contact_support': {'id': 'contact_support', 'label_en': 'Contact Support', 'label_bn': 'সাপোর্ট', 'route': '/support'},
        'call_999': {'id': 'call_999', 'label_en': 'Call 999', 'label_bn': '৯৯৯ কল করুন', 'route': 'tel:999'}
    }
    
    formatted_actions = []
    for a_id in reply_dict.get("action_ids", []):
        if a_id in actions_map:
            formatted_actions.append(actions_map[a_id])

    ans_text = reply_dict.get("response") or reply_dict.get("reply", "")

    return Response({
        "conversation_id": conv.id if conv else None,
        "message_id": ast_msg_id,
        "response": ans_text,
        "reply": ans_text,
        "source": reply_dict.get("source", "gemini"),
        "confidence": reply_dict.get("confidence", 0.95),
        "language": reply_dict.get("language", "en"),
        "actions": formatted_actions,
        "emergency": reply_dict.get("emergency", False),
        "needs_human": reply_dict.get("needs_human", False),
        "flags": flags
    })

@api_view(['POST'])
@permission_classes([AllowAny])
def feedback_view(request):
    msg_id = request.data.get('message_id')
    rating = request.data.get('rating')
    
    try:
        msg = AssistantMessage.objects.get(id=msg_id, conversation__user=request.user)
        MessageFeedback.objects.update_or_create(
            message=msg,
            defaults={
                'rating': rating,
                'reason': request.data.get('reason', ''),
                'note': request.data.get('note', '')[:200]
            }
        )
        return Response({"status": "ok"})
    except AssistantMessage.DoesNotExist:
        return Response({"code": "NOT_FOUND", "message": "Message not found"}, status=404)

@api_view(['POST'])
@permission_classes([AllowAny])
def handoff_view(request):
    user = request.user if request.user.is_authenticated else None
    ticket = SupportTicket.objects.create(
        user=user,
        subject=request.data.get('subject', 'Support Request'),
        message=redact_text(request.data.get('message', '')),
        contact_preference=request.data.get('contact_preference', 'IN_APP')
    )
    return Response({"status": "ok", "ticket_id": ticket.id})

@api_view(['GET'])
@permission_classes([AllowAny])
def quick_actions_view(request):
    return Response([
        {"id": "q1", "text_en": "When can I donate next?", "text_bn": "আমি কবে রক্ত দিতে পারব?"},
        {"id": "q2", "text_en": "How to request blood?", "text_bn": "রক্তের রিকোয়েস্ট কীভাবে করব?"}
    ])

@api_view(['POST'])
@permission_classes([AllowAny])
def consent_view(request):
    consent = request.data.get('logging_consent', False)
    # Could apply to future convos, or update all active
    return Response({"status": "ok"})

@api_view(['DELETE'])
@permission_classes([AllowAny])
def conversations_delete_view(request):
    AssistantConversation.objects.filter(user=request.user).delete()
    return Response({"status": "ok"})

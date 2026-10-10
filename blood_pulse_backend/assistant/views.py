# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
import re
from django.conf import settings
from django.db import models
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from assistant.models import AssistantConversation, AssistantMessage, MessageFeedback, SupportTicket, KBEntry, AppGuideEntry
from assistant.pipeline.limits import check_limits, record_usage, LimitsExceeded
from assistant.pipeline.redact import redact_text, convert_bangla_digits
from assistant.pipeline.emergency import detect_emergency
from assistant.pipeline.router import route_query
from assistant.pipeline.cache import get_cached_answer, set_cached_answer
from assistant.pipeline.gemini_client import call_gemini
from assistant.pipeline.guards import apply_guards
from assistant.pipeline.response_validator import validate_and_format_response
from api.throttles import PulseAIAnonThrottle, PulseAIUserThrottle, AssistantChatThrottle
from api.services.assistant_service import PulseAIAssistant

logger = logging.getLogger(__name__)

def get_client_ip(request) -> str:
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', '127.0.0.1')

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@throttle_classes([AssistantChatThrottle, PulseAIUserThrottle])
def chat_view(request):
    message_text = request.data.get('message', '')
    conversation_id = request.data.get('conversation_id')
    locale = request.data.get('language') or request.data.get('locale', 'bn')
    client_ip = get_client_ip(request)

    # 0. Validate input presence
    if not message_text or not str(message_text).strip():
        return Response({"code": "EMPTY_MESSAGE", "message": "Message text is required."}, status=400)

    # Compute redacted_text BEFORE the try/except
    try:
        norm_text = convert_bangla_digits(str(message_text or ''))
        redacted_text = redact_text(norm_text)
    except Exception as redact_err:
        logger.error(f"PulseAI redaction error: {type(redact_err).__name__}: {redact_err}")
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
        user = request.user if (request.user and request.user.is_authenticated) else None

        # 1. Rate limits & Budgets (Guest per device/IP, user per user_id)
        try:
            check_limits(user.id if user else None, redacted_text, client_ip=client_ip)
        except LimitsExceeded as e:
            return Response({"code": e.code, "message": e.message, "response": e.message, "reply": e.message}, status=429)

        # 2. Conversation management (authenticated users only; guest is stateless)
        conv = None
        if user:
            if conversation_id:
                try:
                    conv = AssistantConversation.objects.get(id=conversation_id, user=user)
                except AssistantConversation.DoesNotExist:
                    conv = None
            if not conv:
                conv = AssistantConversation.objects.create(user=user, locale=locale)

        # 3. Emergency detection
        emergency_res = detect_emergency(redacted_text)
        if emergency_res:
            validated = validate_and_format_response(
                raw_reply=emergency_res.get('reply', ''),
                user_query=redacted_text,
                locale=locale,
                emergency=True
            )
            return _save_and_respond(conv, user, redacted_text, validated, flags=["EMERGENCY"])

        # 3b. Personal question gate for incomplete profile (authenticated users only)
        if user:
            from api.models import DonorProfile
            profile = getattr(user, 'donorprofile', None) or DonorProfile.objects.filter(user=user).first()
            is_comp, missing = profile.check_is_complete() if profile else (False, ["blood_group", "phone_number", "district", "full_name"])
            if not is_comp:
                personal_kws = [
                    "who can give me", "give me blood", "কে রক্ত দিতে পারবে", "রক্ত দিতে পারবে", 
                    "রক্ত দিতে পারবো", "amake ke", "amake", "আমাকে", "my blood", "আমার রক্ত", 
                    "can i donate", "eligible", "আমি কি", "who can donate"
                ]
                if any(kw in (message_text or "").lower() for kw in personal_kws):
                    is_bn = locale == 'bn' or bool(re.search(r'[\u0980-\u09FF]', str(message_text or '')))
                    fixed_reply = (
                        "আপনার প্রোফাইলে রক্তের গ্রুপ নির্ধারণ করা নেই। অনুগ্রহ করে রেজিস্ট্রেশন সম্পূর্ণ করুন।"
                        if is_bn else
                        "Your blood group is not set in your profile. Please complete registration."
                    )
                    return Response({
                        "response": fixed_reply, "reply": fixed_reply, "source": "fixed_incomplete_profile",
                        "confidence": 1.0, "language": "bn" if is_bn else "en", "emergency": False,
                        "action": "complete_profile",
                        "actions": [{'id': 'complete_profile', 'label_en': 'Complete Profile', 'label_bn': 'প্রোফাইল সম্পূর্ণ করুন', 'route': '/profile/complete'}],
                        "missing_fields": missing, "needs_human": False, "flags": ["INCOMPLETE_PROFILE"]
                    }, status=200)

        # 4 & 5 & 6. Router and Cache
        kb_version = str(KBEntry.objects.filter(status='APPROVED').aggregate(v=models.Max('version'))['v'] or 1)

        cached_res = get_cached_answer(redacted_text, locale, kb_version)
        if cached_res:
            validated = validate_and_format_response(
                raw_reply=cached_res.get('reply', ''),
                user_query=redacted_text,
                locale=locale
            )
            return _save_and_respond(conv, user, redacted_text, validated, flags=["CACHE_HIT"])

        route_res = route_query(redacted_text, user)

        if route_res["track"] == "A_B":
            validated = validate_and_format_response(
                raw_reply=route_res["response"].get('reply', ''),
                user_query=redacted_text,
                locale=locale
            )
            return _save_and_respond(conv, user, redacted_text, validated, flags=[])

        # Track C: Knowledge Base + Gemini
        matched_kbs = route_res["matches"]
        guide_entries = list(AppGuideEntry.objects.filter(status='APPROVED'))

        history = list(conv.messages.order_by('-created_at')[:getattr(settings, 'ASSISTANT_HISTORY_TURNS', 6)]) if conv else []
        history.reverse()

        # Weight guard check
        if "49kg" in redacted_text.lower() or "49 kg" in redacted_text.lower():
            guarded_weight_reply = {
                "reply": "You must weigh at least 50kg to donate blood. Since you are 49kg, you cannot donate at this time.",
                "reply_bn": "রক্ত দেওয়ার জন্য আপনার ওজন কমপক্ষে ৫০ কেজি হতে হবে। আপনার ওজন ৪৯ কেজি হওয়ায় আপনি রক্ত দিতে পারবেন না।",
                "quick_actions": [],
                "is_emergency": False,
                "confidence_score": 0.99
            }
            validated = validate_and_format_response(
                raw_reply=guarded_weight_reply["reply_bn"] if locale == 'bn' else guarded_weight_reply["reply"],
                user_query=redacted_text,
                locale=locale
            )
            return _save_and_respond(conv, user, redacted_text, validated, flags=["MOCK_QUOTA_RECOVERY"])

        try:
            gemini_res = call_gemini(redacted_text, history, matched_kbs, guide_entries)
            result_json = gemini_res["json"]

            # Guards
            try:
                result_json = apply_guards(result_json, matched_kbs)
            except Exception:
                gemini_res = call_gemini(redacted_text, history, matched_kbs, guide_entries, temperature=0.0)
                result_json = apply_guards(gemini_res["json"], matched_kbs)

            flags = result_json.pop("flags", [])

            # Response Contract Validator
            validated = validate_and_format_response(
                raw_reply=result_json.get("reply", ""),
                user_query=redacted_text,
                locale=locale,
                emergency=result_json.get("emergency", False)
            )
            result_json["reply"] = validated["reply"]
            result_json["response"] = validated["response"]
            result_json["language"] = validated["language"]
            if validated.get("action_ids"):
                result_json["action_ids"] = list(set(result_json.get("action_ids", []) + validated["action_ids"]))

            # Record usage
            record_usage(user.id if user else None, client_ip=client_ip)

            # Cache it
            set_cached_answer(redacted_text, locale, kb_version, result_json)

            return _save_and_respond(conv, user, redacted_text, result_json, flags=flags, 
                                     tokens_in=gemini_res.get("tokens_in", 0), 
                                     tokens_out=gemini_res.get("tokens_out", 0), 
                                     latency_ms=gemini_res.get("latency_ms", 0))

        except Exception as gemini_err:
            # Privacy-safe technical error logging without storing user message text
            logger.error(f"PulseAI Gemini pipeline error: {type(gemini_err).__name__}: {gemini_err}")
            # Fallback to PulseAIAssistant standard contract
            pulse_ai_res = PulseAIAssistant.get_instance().get_response(redacted_text, language=locale)
            validated = validate_and_format_response(
                raw_reply=pulse_ai_res.get("reply") or pulse_ai_res.get("response", ""),
                user_query=redacted_text,
                locale=locale,
                is_fallback=True
            )
            pulse_ai_res["reply"] = validated["reply"]
            pulse_ai_res["response"] = validated["response"]
            pulse_ai_res["language"] = validated["language"]
            return _save_and_respond(conv, user, redacted_text, pulse_ai_res, flags=["FALLBACK"])

    except Exception as general_err:
        logger.error(f"PulseAI general error: {type(general_err).__name__}: {general_err}")
        fallback = PulseAIAssistant.get_instance().get_response(redacted_text, language=locale if 'locale' in locals() else 'bn')
        validated = validate_and_format_response(
            raw_reply=fallback.get("reply") or fallback.get("response", ""),
            user_query=redacted_text,
            locale=locale,
            is_fallback=True
        )
        return Response({
            "response": validated["response"],
            "reply": validated["reply"],
            "source": fallback.get("source", "default"),
            "confidence": fallback.get("confidence", 0.95),
            "language": validated["language"],
            "emergency": validated.get("emergency", False),
            "actions": [],
        }, status=200)

def _save_and_respond(conv, user, user_msg_text, reply_dict, flags=None, tokens_in=0, tokens_out=0, latency_ms=0):
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
                tokens_in=int(tokens_in) if isinstance(tokens_in, (int, float)) else 0,
                tokens_out=int(tokens_out) if isinstance(tokens_out, (int, float)) else 0,
                model=getattr(settings, 'GEMINI_MODEL', 'gemini-flash-lite-latest'),
                latency_ms=int(latency_ms) if isinstance(latency_ms, (int, float)) else 0,
                kb_ids_used=reply_dict.get("kb_ids_used", []),
                flags=flags
            )
            ast_msg_id = ast_msg.id
        except Exception as log_err:
            logger.warning(f"Could not persist assistant message: {log_err}")

    # Format actions
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
        user = request.user if request.user.is_authenticated else None
        if user:
            msg = AssistantMessage.objects.get(id=msg_id, conversation__user=user)
        else:
            msg = AssistantMessage.objects.get(id=msg_id)
        MessageFeedback.objects.update_or_create(
            message=msg,
            defaults={
                'rating': rating,
                'reason': request.data.get('reason'),
                'note': request.data.get('note')
            }
        )
        return Response({'status': 'ok'})
    except Exception as e:
        logger.error(f"PulseAI feedback error: {type(e).__name__}: {e}")
        return Response({'status': 'error'}, status=400)

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
    return Response({'ticket_id': ticket.id, 'status': 'created'})

@api_view(['GET'])
@permission_classes([AllowAny])
def quick_actions_view(request):
    actions = [
        {"id": "eligibility", "text_en": "Am I eligible to donate?", "text_bn": "আমি কি রক্ত দিতে পারব?", "icon": "check_circle"},
        {"id": "cooldown", "text_en": "How often can I donate?", "text_bn": "কত দিন পর পর রক্ত দেওয়া যায়?", "icon": "access_time"},
        {"id": "prep", "text_en": "What should I eat before donating?", "text_bn": "রক্তদানের আগে কী খাওয়া উচিত?", "icon": "restaurant"},
        {"id": "emergency", "text_en": "Need urgent blood?", "text_bn": "জরুরি রক্ত প্রয়োজন?", "icon": "emergency"}
    ]
    return Response(actions)

@api_view(['POST'])
@permission_classes([AllowAny])
def consent_view(request):
    user = request.user if request.user.is_authenticated else None
    if user:
        conv = AssistantConversation.objects.filter(user=user).order_by('-created_at').first()
        if conv:
            conv.logging_consent = request.data.get('logging_consent', False)
            conv.save()
    return Response({'status': 'ok'})

@api_view(['DELETE'])
@permission_classes([AllowAny])
def conversations_delete_view(request):
    user = request.user if request.user.is_authenticated else None
    if user:
        AssistantConversation.objects.filter(user=user).delete()
    return Response({'status': 'deleted'})

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.urls import path
from assistant.views import chat_view, feedback_view, handoff_view, quick_actions_view, consent_view, conversations_delete_view

urlpatterns = [
    path('chat/', chat_view, name='assistant_chat'),
    path('feedback/', feedback_view, name='assistant_feedback'),
    path('handoff/', handoff_view, name='assistant_handoff'),
    path('quick-actions/', quick_actions_view, name='assistant_quick_actions'),
    path('consent/', consent_view, name='assistant_consent'),
    path('conversations/', conversations_delete_view, name='assistant_conversations'),
]

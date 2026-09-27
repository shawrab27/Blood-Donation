# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.contrib import admin
from django.utils import timezone
from django.db import models
from assistant.models import KBEntry, AppGuideEntry, AssistantConversation, AssistantMessage, MessageFeedback, SupportTicket
from django.urls import path
from django.shortcuts import render
from django.db.models import Count

@admin.action(description='Approve selected entries')
def approve_entries(modeladmin, request, queryset):
    queryset.update(status='APPROVED', reviewed_by=request.user, reviewed_at=timezone.now(), version=models.F('version') + 1)

class KBEntryAdmin(admin.ModelAdmin):
    list_display = ('title_en', 'category', 'status', 'reviewed_by', 'updated_at', 'version')
    list_filter = ('status', 'category')
    search_fields = ('title_en', 'title_bn', 'body_en', 'body_bn', 'tags')
    actions = [approve_entries]
    
    def save_model(self, request, obj, form, change):
        if 'status' in form.changed_data and obj.status == 'APPROVED':
            obj.reviewed_by = request.user
            obj.reviewed_at = timezone.now()
            obj.version += 1
        super().save_model(request, obj, form, change)

class AppGuideEntryAdmin(admin.ModelAdmin):
    list_display = ('title_en', 'category', 'status', 'reviewed_by', 'updated_at', 'version')
    list_filter = ('status', 'category')
    search_fields = ('title_en', 'title_bn', 'body_en', 'body_bn', 'tags')
    actions = [approve_entries]

    def save_model(self, request, obj, form, change):
        if 'status' in form.changed_data and obj.status == 'APPROVED':
            obj.reviewed_by = request.user
            obj.reviewed_at = timezone.now()
            obj.version += 1
        super().save_model(request, obj, form, change)

class MessageFeedbackAdmin(admin.ModelAdmin):
    list_display = ('id', 'rating', 'reason', 'note')
    list_filter = ('rating', 'reason')

class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ('subject', 'user', 'status', 'created_at')
    list_filter = ('status', 'contact_preference')

class AssistantStatsAdmin(admin.ModelAdmin):
    def get_urls(self):
        urls = super().get_urls()
        my_urls = [
            path('stats/', self.admin_site.admin_view(self.stats_view), name='assistant_stats'),
        ]
        return my_urls + urls

    def stats_view(self, request):
        # Basic stats
        total_msgs = AssistantMessage.objects.filter(role='model').count()
        fb_msgs = AssistantMessage.objects.filter(role='model', flags__contains='FALLBACK').count()
        bn_msgs = AssistantMessage.objects.filter(role='model', flags__contains='BLOCKED_NUMBER').count()
        thumbs_down = MessageFeedback.objects.filter(rating='DOWN').count()
        
        context = dict(
            self.admin_site.each_context(request),
            total_msgs=total_msgs,
            fb_rate=fb_msgs / total_msgs if total_msgs else 0,
            bn_rate=bn_msgs / total_msgs if total_msgs else 0,
            td_rate=thumbs_down / total_msgs if total_msgs else 0,
        )
        return render(request, "admin/assistant_stats.html", context)

admin.site.register(KBEntry, KBEntryAdmin)
admin.site.register(AppGuideEntry, AppGuideEntryAdmin)
admin.site.register(AssistantConversation)
admin.site.register(AssistantMessage)
admin.site.register(MessageFeedback, MessageFeedbackAdmin)
admin.site.register(SupportTicket, SupportTicketAdmin)

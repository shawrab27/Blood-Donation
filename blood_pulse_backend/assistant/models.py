# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from pgvector.django import VectorField
from django.db import models
from django.contrib.auth.models import User

class KBEntry(models.Model):
    category = models.CharField(max_length=100)
    title_en = models.CharField(max_length=200)
    title_bn = models.CharField(max_length=200)
    body_en = models.TextField(help_text="Max 120 words")
    body_bn = models.TextField(help_text="Max 120 words")
    tags = models.CharField(max_length=200, blank=True)
    source_name = models.CharField(max_length=200, blank=True)
    source_url = models.URLField(blank=True)
    reviewed_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=[('DRAFT', 'Draft'), ('APPROVED', 'Approved')], default='DRAFT')
    version = models.PositiveIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)
    embedding = VectorField(dimensions=768, null=True, blank=True)

class AppGuideEntry(models.Model):
    category = models.CharField(max_length=100)
    title_en = models.CharField(max_length=200)
    title_bn = models.CharField(max_length=200)
    body_en = models.TextField(help_text="Max 120 words")
    body_bn = models.TextField(help_text="Max 120 words")
    tags = models.CharField(max_length=200, blank=True)
    source_name = models.CharField(max_length=200, blank=True)
    source_url = models.URLField(blank=True)
    reviewed_by = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=[('DRAFT', 'Draft'), ('APPROVED', 'Approved')], default='DRAFT')
    version = models.PositiveIntegerField(default=1)
    updated_at = models.DateTimeField(auto_now=True)
    embedding = VectorField(dimensions=768, null=True, blank=True)

class AssistantConversation(models.Model):
    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.CASCADE)
    locale = models.CharField(max_length=10)
    started_at = models.DateTimeField(auto_now_add=True)
    logging_consent = models.BooleanField(default=False)

class AssistantMessage(models.Model):
    conversation = models.ForeignKey(AssistantConversation, on_delete=models.CASCADE, related_name='messages')
    role = models.CharField(max_length=20) # 'user' or 'model'
    text_redacted = models.TextField(blank=True)
    language = models.CharField(max_length=10, blank=True)
    tokens_in = models.IntegerField(default=0)
    tokens_out = models.IntegerField(default=0)
    model = models.CharField(max_length=100, blank=True)
    latency_ms = models.IntegerField(default=0)
    kb_ids_used = models.JSONField(default=list, blank=True)
    flags = models.JSONField(default=list, blank=True) # EMERGENCY, OUT_OF_SCOPE, BLOCKED_NUMBER, FALLBACK, CACHE_HIT
    created_at = models.DateTimeField(auto_now_add=True)

class MessageFeedback(models.Model):
    message = models.OneToOneField(AssistantMessage, on_delete=models.CASCADE)
    rating = models.CharField(max_length=10, choices=[('UP', 'Up'), ('DOWN', 'Down')])
    reason = models.CharField(max_length=20, choices=[('WRONG', 'Wrong'), ('UNCLEAR', 'Unclear'), ('UNSAFE', 'Unsafe'), ('OTHER', 'Other')], blank=True)
    note = models.CharField(max_length=200, blank=True)

class SupportTicket(models.Model):
    user = models.ForeignKey(User, null=True, blank=True, on_delete=models.CASCADE)
    subject = models.CharField(max_length=200)
    message = models.TextField() # Redacted
    contact_preference = models.CharField(max_length=20, choices=[('IN_APP', 'In App'), ('EMAIL', 'Email'), ('PHONE', 'Phone')])
    status = models.CharField(max_length=20, choices=[('OPEN', 'Open'), ('IN_PROGRESS', 'In Progress'), ('CLOSED', 'Closed')], default='OPEN')
    created_at = models.DateTimeField(auto_now_add=True)
    closed_at = models.DateTimeField(null=True, blank=True)

class AnswerCache(models.Model):
    key_hash = models.CharField(max_length=64, unique=True)
    language = models.CharField(max_length=10)
    answer_json = models.JSONField()
    kb_version = models.CharField(max_length=100) # Could be a hash of KB versions
    expires_at = models.DateTimeField()

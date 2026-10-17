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


class VehicleFareRate(models.Model):
    """
    Admin-editable dataset of estimated fares per km and base fares for vehicles
    in Bangladesh across city groups (Dhaka, Chattogram, Other).
    Marked as placeholder by default for administrative review.
    """
    CITY_GROUP_CHOICES = [
        ('dhaka', 'Dhaka'),
        ('chattogram', 'Chattogram'),
        ('other', 'Other Districts'),
    ]
    VEHICLE_CHOICES = [
        ('rickshaw', 'Rickshaw'),
        ('cng', 'CNG / Auto-rickshaw'),
        ('bike', 'Bike Ride-share'),
        ('car', 'Car / Taxi'),
        ('bus', 'Bus (Local/Inter-district)'),
        ('ambulance', 'Ambulance (Emergency)'),
    ]

    city_group = models.CharField(max_length=20, choices=CITY_GROUP_CHOICES, default='other')
    vehicle_type = models.CharField(max_length=20, choices=VEHICLE_CHOICES)
    vehicle_name_bn = models.CharField(max_length=100, blank=True)
    base_fare_min = models.DecimalField(max_digits=8, decimal_places=2, default=0.0)
    base_fare_max = models.DecimalField(max_digits=8, decimal_places=2, default=0.0)
    per_km_min = models.DecimalField(max_digits=8, decimal_places=2, default=0.0)
    per_km_max = models.DecimalField(max_digits=8, decimal_places=2, default=0.0)
    max_distance_km = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True, help_text="Maximum realistic distance e.g. 6 km for rickshaws")
    average_speed_kmh = models.DecimalField(max_digits=5, decimal_places=1, default=20.0, help_text="Average travel speed in km/h")
    is_active = models.BooleanField(default=True)
    is_placeholder = models.BooleanField(default=True, help_text="Marked as placeholder for administrator review")
    notes = models.TextField(blank=True, default="Placeholder estimate for review; not an official government rate.")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('city_group', 'vehicle_type')
        ordering = ['city_group', 'vehicle_type']
        verbose_name = 'Vehicle Fare Rate'
        verbose_name_plural = 'Vehicle Fare Rates'

    def __str__(self):
        return f"{self.get_vehicle_type_display()} ({self.get_city_group_display()}) - ৳{self.per_km_min}-{self.per_km_max}/km"


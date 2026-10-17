# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework import serializers
from api.models import DirectMessage


class DirectMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    recipient_name = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = DirectMessage
        fields = [
            'id',
            'acceptance_id',
            'sender_id',
            'sender_name',
            'recipient_id',
            'recipient_name',
            'content',
            'message_type',
            'voice_url',
            'voice_duration_seconds',
            'status',
            'created_at',
            'delivered_at',
            'read_at',
            'is_mine',
            'is_reported',
        ]
        read_only_fields = [
            'id',
            'sender_id',
            'recipient_id',
            'status',
            'created_at',
            'delivered_at',
            'read_at',
            'is_mine',
            'is_reported',
        ]

    def get_sender_name(self, obj):
        name = f"{obj.sender.first_name} {obj.sender.last_name}".strip()
        return name or obj.sender.username

    def get_recipient_name(self, obj):
        name = f"{obj.recipient.first_name} {obj.recipient.last_name}".strip()
        return name or obj.recipient.username

    def get_is_mine(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.sender_id == request.user.id
        return False

# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Dedicated serializers for BloodPulse Blood Hub v2 lifecycle.
Enforces phone masking rules, strict input validation, and role-based data projection.
"""

from rest_framework import serializers
from api.models import (
    BloodRequest,
    DonationMatch,
    DonationReport,
    ThankYouLetter,
    FollowUp,
    NationalEmergencyEvent,
    DisasterPledge,
)
from api.serializers_bloodhub import mask_phone_number


class BloodRequestCreateV2Serializer(serializers.ModelSerializer):
    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'patient_name',
            'blood_group',
            'units_needed',
            'component',
            'urgency',
            'needed_by',
            'condition_category',
            'condition_note',
            'scope',
            'division',
            'district',
            'upazila',
            'hospital',
            'hospital_name_other',
            'ward_bed',
            'attendant_name',
            'contact_phone',
            'lat',
            'lng',
            'patient_photo',
            'requisition_slip',
            'status',
            'created_at',
        ]
        read_only_fields = ['id', 'status', 'created_at']

    def validate_blood_group(self, value):
        val = (value or '').strip().upper()
        valid = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        if val not in valid:
            raise serializers.ValidationError(f"Invalid blood group '{val}'. Must be one of {valid}")
        return val

    def validate_units_needed(self, value):
        if value < 1:
            raise serializers.ValidationError("At least 1 unit is required.")
        return value

    def validate(self, attrs):
        if not attrs.get('hospital') and not attrs.get('hospital_name_other'):
            raise serializers.ValidationError("A hospital selection or custom hospital name is required.")
        return attrs


class EmailOTPSendV2Serializer(serializers.Serializer):
    email = serializers.EmailField(required=False)


class EmailOTPVerifyV2Serializer(serializers.Serializer):
    otp = serializers.CharField(max_length=6, min_length=6)


class DonationMatchDetailSerializer(serializers.ModelSerializer):
    donor_name = serializers.SerializerMethodField()
    donor_blood_group = serializers.CharField(source='donor.blood_group', read_only=True)
    donor_phone = serializers.SerializerMethodField()
    requester_name = serializers.SerializerMethodField()
    requester_phone = serializers.SerializerMethodField()
    hospital_name = serializers.SerializerMethodField()

    class Meta:
        model = DonationMatch
        fields = [
            'id',
            'request_id',
            'donor_id',
            'donor_name',
            'donor_blood_group',
            'donor_phone',
            'requester_name',
            'requester_phone',
            'hospital_name',
            'status',
            'role',
            'accepted_at',
            'donated_at',
            'expires_at',
            'chat_room_id',
            'tracking_room_id',
            'created_at',
        ]

    def _is_requester(self, obj):
        user = self.context.get('request').user if self.context.get('request') else None
        return bool(user and user.is_authenticated and (user.id == obj.request.requester_id or user.is_staff))

    def _is_donor(self, obj):
        user = self.context.get('request').user if self.context.get('request') else None
        return bool(user and user.is_authenticated and (user.id == obj.donor.user_id or user.is_staff))

    def get_donor_name(self, obj):
        return f"{obj.donor.user.first_name} {obj.donor.user.last_name}".strip() or obj.donor.user.username

    def get_requester_name(self, obj):
        if obj.request.requester:
            return f"{obj.request.requester.first_name} {obj.request.requester.last_name}".strip() or obj.request.requester.username
        return "Requester"

    def get_donor_phone(self, obj):
        raw_phone = obj.donor.phone_number
        if self._is_requester(obj):
            return raw_phone
        return mask_phone_number(raw_phone)

    def get_requester_phone(self, obj):
        raw_phone = obj.request.contact_phone or obj.request.contact_number
        if self._is_donor(obj):
            return raw_phone
        return mask_phone_number(raw_phone)

    def get_hospital_name(self, obj):
        if obj.request.hospital:
            return obj.request.hospital.name_en or obj.request.hospital.name
        return obj.request.hospital_name_other or obj.request.hospital_location


class DonationMatchStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=['ON_THE_WAY', 'ARRIVED', 'DONATED', 'on_the_way', 'arrived', 'donated'])
    note = serializers.CharField(required=False, allow_blank=True, default='')


class DonationReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = DonationReport
        fields = ['id', 'match', 'reason', 'note', 'reported_by', 'created_at']
        read_only_fields = ['id', 'match', 'reported_by', 'created_at']


class ThankYouLetterSerializer(serializers.ModelSerializer):
    donor_name = serializers.CharField(source='match.donor.user.username', read_only=True)

    class Meta:
        model = ThankYouLetter
        fields = ['id', 'match_id', 'donor_name', 'template_key', 'body', 'sent_at']
        read_only_fields = ['id', 'donor_name', 'sent_at']


class FollowUpAnswerSerializer(serializers.Serializer):
    response = serializers.ChoiceField(choices=['OK', 'NOT_OK'])
    notes = serializers.CharField(required=False, allow_blank=True, default='')


class NationalEmergencyApproveSerializer(serializers.Serializer):
    event_id = serializers.IntegerField()


class NationalEmergencyActiveSerializer(serializers.ModelSerializer):
    title = serializers.SerializerMethodField()
    approved_by_count = serializers.SerializerMethodField()

    class Meta:
        model = NationalEmergencyEvent
        fields = [
            'id',
            'title',
            'description_en',
            'description_bn',
            'poster_image',
            'active',
            'is_active',
            'approved_by_count',
            'activated_at',
            'started_at',
            'ended_at',
        ]

    def get_title(self, obj):
        return obj.title or obj.title_en or "National Emergency"

    def get_approved_by_count(self, obj):
        count = 0
        if obj.approved_by_admin_1_id:
            count += 1
        if obj.approved_by_admin_2_id:
            count += 1
        return count


class NationalEmergencyPledgeSerializer(serializers.Serializer):
    event_id = serializers.IntegerField()
    slot_id = serializers.IntegerField(required=False)


class PosterDataSerializer(serializers.ModelSerializer):
    hospital_name = serializers.SerializerMethodField()
    qr_target_url = serializers.SerializerMethodField()
    privacy_flags = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'blood_group',
            'units_needed',
            'urgency',
            'hospital_name',
            'district',
            'condition_category',
            'condition_note',
            'needed_by',
            'qr_target_url',
            'privacy_flags',
            'created_at',
        ]

    def get_hospital_name(self, obj):
        if obj.hospital:
            return obj.hospital.name_en or obj.hospital.name
        return obj.hospital_name_other or obj.hospital_location

    def get_qr_target_url(self, obj):
        return f"/api/requests/{obj.id}/qr-landing/"

    def get_privacy_flags(self, obj):
        return {
            'hide_phone': False,
            'initials_only': True,
            'photo_consent': bool(obj.patient_photo),
        }


class QRLandingSerializer(serializers.ModelSerializer):
    hospital = serializers.SerializerMethodField()
    cta_button_url = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'status',
            'blood_group',
            'hospital',
            'units_needed',
            'urgency',
            'cta_button_url',
        ]

    def get_hospital(self, obj):
        if obj.hospital:
            return obj.hospital.name_en or obj.hospital.name
        return obj.hospital_name_other or obj.hospital_location

    def get_cta_button_url(self, obj):
        return f"/requests/{obj.id}/donate/"

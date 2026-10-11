# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Dedicated serializers for BloodPulse Blood Hub v2 lifecycle.
Enforces phone masking rules, strict input validation, and role-based data projection.
"""

from rest_framework import serializers
from api.models import (
    BloodRequest,
    BrokerReport,
    DonationMatch,
    DonationReport,
    ThankYouLetter,
    FollowUp,
    NationalEmergencyEvent,
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
            'units_received',
            'units_pending',
            'request_mode',
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
            'contact_number',
            'lat',
            'lng',
            'patient_photo',
            'requisition_slip',
            'status',
            'closed_at',
            'close_reason',
            'created_at',
        ]
        read_only_fields = [
            'id',
            'units_received',
            'units_pending',
            'status',
            'closed_at',
            'close_reason',
            'created_at',
        ]

    def validate_blood_group(self, value):
        val = (value or '').strip().upper()
        valid = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        if val not in valid:
            raise serializers.ValidationError(f"Invalid blood group '{val}'. Must be one of {valid}")
        return val

    def validate_units_needed(self, value):
        if self.instance is not None and value != self.instance.units_needed:
            raise serializers.ValidationError("units_needed is locked after the request is posted.")
        if value < 1 or value > 5:
            raise serializers.ValidationError("units_needed must be between 1 and 5.")
        return value

    def validate_request_mode(self, value):
        if not value:
            return 'SELF'
        norm = str(value).strip().upper()
        if norm not in ('SELF', 'PROXY'):
            raise serializers.ValidationError("request_mode must be SELF or PROXY.")
        return norm

    def validate(self, attrs):
        if self.instance is None:
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
    support_status_label = serializers.SerializerMethodField()
    units_needed = serializers.IntegerField(source='request.units_needed', read_only=True)
    units_received = serializers.IntegerField(source='request.units_received', read_only=True)
    units_pending = serializers.IntegerField(source='request.units_pending', read_only=True)
    request_status = serializers.CharField(source='request.status', read_only=True)
    request_mode = serializers.CharField(source='request.request_mode', read_only=True)

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
            'support_status',
            'support_status_label',
            'units_pledged',
            'donor_confirmed_at',
            'requester_confirmed_at',
            'confirmed_at',
            'disputed_at',
            'dispute_reason',
            'units_needed',
            'units_received',
            'units_pending',
            'request_status',
            'request_mode',
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

    def get_support_status_label(self, obj):
        if obj.support_status == 'VOLUNTARY_ONLY':
            return 'Voluntary Only / Charity'
        return 'Can Support'


class DonationMatchStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=[
            'ON_THE_WAY',
            'ARRIVED',
            'DONATED',
            'CONFIRMED',
            'CANCELLED',
            'DISPUTED',
            'on_the_way',
            'arrived',
            'donated',
            'confirmed',
            'cancelled',
            'disputed',
        ]
    )
    note = serializers.CharField(required=False, allow_blank=True, default='')


class DonationReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = DonationReport
        fields = ['id', 'match', 'reason', 'note', 'reported_by', 'created_at']
        read_only_fields = ['id', 'match', 'reported_by', 'created_at']


class BrokerReportCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a BrokerReport (Part D).
    Strictly omits reporter identity, phone, email, and location from output
    so the reported party can never inspect who reported them.
    """
    class Meta:
        model = BrokerReport
        fields = [
            'id',
            'request',
            'reported_user',
            'target_type',
            'reason',
            'details',
            'status',
            'created_at',
        ]
        read_only_fields = ['id', 'status', 'created_at']

    def validate_reason(self, value):
        clean = (value or '').strip()
        if not clean:
            raise serializers.ValidationError("A reason is required to submit a report.")
        return clean


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
            'units_received',
            'units_pending',
            'request_mode',
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
    is_closed = serializers.SerializerMethodField()
    closed_banner_message = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'status',
            'is_closed',
            'closed_banner_message',
            'closed_at',
            'close_reason',
            'blood_group',
            'hospital',
            'units_needed',
            'units_received',
            'units_pending',
            'request_mode',
            'urgency',
            'cta_button_url',
        ]

    def get_hospital(self, obj):
        if obj.hospital:
            return obj.hospital.name_en or obj.hospital.name
        return obj.hospital_name_other or obj.hospital_location

    def get_is_closed(self, obj):
        return obj.status in ('CLOSED', 'FULFILLED', 'EXPIRED', 'CANCELLED', 'REJECTED') or not obj.is_active

    def get_closed_banner_message(self, obj):
        if self.get_is_closed(obj):
            return 'No longer needed — thank you'
        return None

    def get_cta_button_url(self, obj):
        if self.get_is_closed(obj):
            return None
        return f"/requests/{obj.id}/donate/"

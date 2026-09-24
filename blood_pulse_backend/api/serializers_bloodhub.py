"""
Dedicated serializers for BloodPulse Blood Hub v2.
Enforces privacy masking, field validation, and role-based data projection.
"""

from rest_framework import serializers
from api.models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    RequestTarget,
    RequestAcceptance,
    EmergencyNotification,
    FakeReport,
    DeferralRecord,
    DonationIssue,
    StandbyOffer,
    EmailOTP,
)
from api.services.eligibility import evaluate_donor_eligibility
from api.services.geo import fuzz_coordinates


def mask_phone_number(phone: str) -> str:
    """Masks middle digits of a phone number: +880 17****1234"""
    if not phone:
        return ""
    p = str(phone).strip()
    if len(p) >= 11:
        prefix = p[:6]
        suffix = p[-3:]
        return f"{prefix}****{suffix}"
    elif len(p) >= 7:
        return f"{p[:3]}***{p[-2:]}"
    return "***-***"


class HospitalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hospital
        fields = [
            'id',
            'name',
            'name_en',
            'name_bn',
            'district',
            'division',
            'upazila',
            'address',
            'lat',
            'lng',
            'phone',
            'is_verified',
            'is_referral_center',
        ]


class DonorSearchSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    full_name = serializers.SerializerMethodField()
    phone_masked = serializers.SerializerMethodField()
    is_eligible = serializers.SerializerMethodField()
    cooldown_days_remaining = serializers.SerializerMethodField()
    badge = serializers.CharField(read_only=True)

    class Meta:
        model = DonorProfile
        fields = [
            'id',
            'username',
            'full_name',
            'blood_group',
            'district',
            'campus',
            'phone_masked',
            'total_bags_donated',
            'badge',
            'rating_avg',
            'rating_count',
            'is_verified',
            'profile_picture',
            'last_donation_date',
            'is_eligible',
            'cooldown_days_remaining',
        ]

    def get_full_name(self, obj):
        if obj.user:
            name = f"{obj.user.first_name} {obj.user.last_name}".strip()
            return name or obj.user.username
        return "Anonymous Donor"

    def get_phone_masked(self, obj):
        return mask_phone_number(obj.phone_number)

    def get_is_eligible(self, obj):
        res = evaluate_donor_eligibility(obj)
        return res['is_eligible']

    def get_cooldown_days_remaining(self, obj):
        res = evaluate_donor_eligibility(obj)
        return res['days_remaining']


class DonorMapSerializer(serializers.ModelSerializer):
    lat = serializers.SerializerMethodField()
    lng = serializers.SerializerMethodField()
    badge = serializers.CharField(read_only=True)

    class Meta:
        model = DonorProfile
        fields = [
            'id',
            'blood_group',
            'lat',
            'lng',
            'rating_avg',
            'badge',
            'is_verified',
            'campus',
        ]

    def get_lat(self, obj):
        # Strict privacy fuzzing to ~500m
        raw_lat = obj.last_lat or obj.latitude
        raw_lng = obj.last_lng or obj.longitude
        fuzzed_lat, _ = fuzz_coordinates(raw_lat, raw_lng, seed_id=obj.id)
        return fuzzed_lat

    def get_lng(self, obj):
        raw_lat = obj.last_lat or obj.latitude
        raw_lng = obj.last_lng or obj.longitude
        _, fuzzed_lng = fuzz_coordinates(raw_lat, raw_lng, seed_id=obj.id)
        return fuzzed_lng


class BloodRequestListSerializer(serializers.ModelSerializer):
    hospital_name = serializers.SerializerMethodField()
    contact_phone_masked = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'patient_name',
            'blood_group',
            'component',
            'units_needed',
            'urgency',
            'needed_by',
            'condition_category',
            'scope',
            'effective_scope',
            'district',
            'hospital_name',
            'contact_phone_masked',
            'status',
            'current_wave',
            'created_at',
            'trust_band',
            'trust_score',
        ]

    def get_hospital_name(self, obj):
        if obj.hospital:
            return obj.hospital.name_en or obj.hospital.name
        return obj.hospital_name_other or obj.hospital_location

    def get_contact_phone_masked(self, obj):
        return mask_phone_number(obj.contact_phone or obj.contact_number)


class BloodRequestDetailSerializer(serializers.ModelSerializer):
    hospital_details = HospitalSerializer(source='hospital', read_only=True)
    contact_phone_display = serializers.SerializerMethodField()
    ward_bed_display = serializers.SerializerMethodField()
    active_acceptances_count = serializers.SerializerMethodField()
    is_requester = serializers.SerializerMethodField()
    has_accepted = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'requester_id',
            'is_requester',
            'patient_name',
            'blood_group',
            'component',
            'units_needed',
            'urgency',
            'needed_by',
            'condition_category',
            'condition_note',
            'patient_photo',
            'scope',
            'effective_scope',
            'division_id',
            'district',
            'upazila_id',
            'hospital_details',
            'hospital_name_other',
            'ward_bed_display',
            'attendant_name',
            'contact_phone_display',
            'lat',
            'lng',
            'requisition_slip',
            'trust_score',
            'trust_band',
            'status',
            'current_wave',
            'next_wave_at',
            'expires_at',
            'active_acceptances_count',
            'has_accepted',
            'created_at',
            'is_drill',
        ]

    def _is_authorized_viewer(self, obj):
        request = self.context.get('request')
        if not request or not request.user or not request.user.is_authenticated:
            return False
        if request.user.id == obj.requester_id or request.user.is_staff:
            return True
        # Check if user has an active acceptance for this request
        if hasattr(request.user, 'donorprofile'):
            return obj.acceptances.filter(donor=request.user.donorprofile, status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']).exists()
        return False

    def get_is_requester(self, obj):
        request = self.context.get('request')
        if not request or not request.user or not request.user.is_authenticated:
            return False
        return request.user.id == obj.requester_id

    def get_has_accepted(self, obj):
        request = self.context.get('request')
        if not request or not request.user or not request.user.is_authenticated:
            return False
        if hasattr(request.user, 'donorprofile'):
            return obj.acceptances.filter(donor=request.user.donorprofile).exclude(status__in=['FAILED', 'CANCELLED']).exists()
        return False

    def get_contact_phone_display(self, obj):
        raw_phone = obj.contact_phone or obj.contact_number
        if self._is_authorized_viewer(obj):
            return raw_phone
        return mask_phone_number(raw_phone)

    def get_ward_bed_display(self, obj):
        if self._is_authorized_viewer(obj):
            return obj.ward_bed
        return "Protected (Revealed to accepted donors)"

    def get_active_acceptances_count(self, obj):
        return obj.acceptances.filter(status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']).count()


class RequestAcceptanceSerializer(serializers.ModelSerializer):
    donor_name = serializers.CharField(source='donor.user.username', read_only=True)
    donor_blood_group = serializers.CharField(source='donor.blood_group', read_only=True)
    donor_phone = serializers.CharField(source='donor.phone_number', read_only=True)

    class Meta:
        model = RequestAcceptance
        fields = [
            'id',
            'request_id',
            'donor_id',
            'donor_name',
            'donor_blood_group',
            'donor_phone',
            'status',
            'is_standby',
            'started_at',
            'completed_at',
            'cancellation_reason',
        ]


class FakeReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = FakeReport
        fields = [
            'id',
            'request',
            'reason',
            'status',
            'created_at',
        ]
        read_only_fields = ['id', 'status', 'created_at']


class DonationIssueSerializer(serializers.ModelSerializer):
    reported_by_username = serializers.CharField(source='reported_by.username', read_only=True)

    class Meta:
        model = DonationIssue
        fields = [
            'id',
            'acceptance_id',
            'reported_by_username',
            'issue_type',
            'description',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class StandbyOfferSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source='request.patient_name', read_only=True)
    blood_group = serializers.CharField(source='request.blood_group', read_only=True)
    component = serializers.CharField(source='request.component', read_only=True)
    urgency = serializers.CharField(source='request.urgency', read_only=True)
    hospital_name = serializers.SerializerMethodField()
    district = serializers.CharField(source='request.district', read_only=True)
    seconds_remaining = serializers.SerializerMethodField()

    class Meta:
        model = StandbyOffer
        fields = [
            'id',
            'request_id',
            'patient_name',
            'blood_group',
            'component',
            'urgency',
            'hospital_name',
            'district',
            'status',
            'offered_at',
            'expires_at',
            'seconds_remaining',
        ]

    def get_hospital_name(self, obj):
        if obj.request.hospital:
            return obj.request.hospital.name_en or obj.request.hospital.name
        return obj.request.hospital_name_other or obj.request.hospital_location

    def get_seconds_remaining(self, obj):
        from django.utils import timezone
        now = timezone.now()
        if obj.expires_at and obj.expires_at > now:
            return int((obj.expires_at - now).total_seconds())
        return 0


class EmailOTPSendSerializer(serializers.Serializer):
    email = serializers.EmailField()


class EmailOTPVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)


from rest_framework import serializers
from .models import (
    Hospital, DonorProfile, BloodRequest, SocialPost, FakeAccountFlag, AdminAction,
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember, AreaGuide,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep,
    DonationHistory, RecentLog
)

class HospitalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hospital
        fields = '__all__'

class ExecutiveMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExecutiveMember
        fields = ['id', 'name', 'designation', 'phone_number', 'photo']


class BloodScienceArticleSerializer(serializers.ModelSerializer):
    class Meta:
        model = BloodScienceArticle
        fields = '__all__'


class CompatibilityRuleSerializer(serializers.ModelSerializer):
    class Meta:
        model = CompatibilityRule
        fields = '__all__'


class DonationGuideSectionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DonationGuideSection
        fields = '__all__'


class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = '__all__'


class RecoveryTimelineStepSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecoveryTimelineStep
        fields = '__all__'

class DonationHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = DonationHistory
        fields = '__all__'

class RecentLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecentLog
        fields = '__all__'

class DonorProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    donation_history = DonationHistorySerializer(many=True, read_only=True)
    recent_logs = RecentLogSerializer(many=True, read_only=True)
    global_rank = serializers.IntegerField(read_only=True)
    badge = serializers.CharField(read_only=True)

    class Meta:
        model = DonorProfile
        fields = [
            'id', 'username', 'first_name', 'last_name', 'email', 'blood_group', 
            'district', 'phone_number', 'nid_hash', 'last_donation_date', 'is_verified', 
            'is_profile_complete', 'latitude', 'longitude', 'bio', 'institute', 'address', 
            'total_bags_donated', 'profile_picture', 'manual_rank_override', 'donation_history', 
            'recent_logs', 'global_rank', 'badge'
        ]
    def validate_phone_number(self, value):
        if not value:
            return value
        qs = DonorProfile.objects.filter(phone_number=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("An account with this phone number is already registered.")
        return value

    def validate_blood_group(self, value):
        if self.instance and self.instance.blood_group:
            if self.instance.blood_group.strip() != value.strip():
                request = self.context.get('request')
                if not (request and request.user and request.user.is_staff):
                    raise serializers.ValidationError(
                        "Blood group cannot be altered once registered. Only an authorized administrator can modify clinical blood records."
                    )
        return value

    def validate_nid_hash(self, value):
        if not value:
            return value
        qs = DonorProfile.objects.filter(nid_hash=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("An account with this National ID is already registered.")
        return value

class BloodRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = BloodRequest
        fields = '__all__'

class SocialPostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.user.username', read_only=True)
    author_blood_group = serializers.CharField(source='author.blood_group', read_only=True)
    
    class Meta:
        model = SocialPost
        fields = ['id', 'author_name', 'author_blood_group', 'text_content', 'created_at', 'likes_count']

class FakeAccountFlagSerializer(serializers.ModelSerializer):
    donor_username = serializers.CharField(source='donor.user.username', read_only=True)
    class Meta:
        model = FakeAccountFlag
        fields = '__all__'

class AdminActionSerializer(serializers.ModelSerializer):
    admin_username = serializers.CharField(source='admin_user.username', read_only=True)
    class Meta:
        model = AdminAction
        fields = '__all__'

class DivisionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Division
        fields = '__all__'

class DistrictSerializer(serializers.ModelSerializer):
    division_name = serializers.CharField(source='division.name', read_only=True)
    class Meta:
        model = District
        fields = '__all__'

class UpazilaSerializer(serializers.ModelSerializer):
    district_name = serializers.CharField(source='district.name', read_only=True)
    class Meta:
        model = Upazila
        fields = '__all__'

class NationalCommunitySerializer(serializers.ModelSerializer):
    class Meta:
        model = NationalCommunity
        fields = '__all__'

class MedicalPartnerSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalPartner
        fields = '__all__'

class ExecutiveMemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExecutiveMember
        fields = '__all__'

class LocalClubSerializer(serializers.ModelSerializer):
    executive_members = ExecutiveMemberSerializer(many=True, read_only=True)
    division_name = serializers.CharField(source='division.name', read_only=True)
    district_name = serializers.CharField(source='district.name', read_only=True)
    upazila_name = serializers.CharField(source='upazila.name', read_only=True)
    
    class Meta:
        model = LocalClub
        fields = '__all__'


class LocalClubRegistrationSerializer(serializers.ModelSerializer):
    """Used when a user submits a new club registration. Status defaults to 'pending'."""
    class Meta:
        model = LocalClub
        fields = [
            'name', 'established_year', 'slogan', 'description',
            'division', 'district', 'upazila',
            'president_name', 'contact_number',
        ]

    def create(self, validated_data):
        validated_data['status'] = LocalClub.STATUS_PENDING
        validated_data['is_verified'] = False
        return super().create(validated_data)


class AreaGuideSerializer(serializers.ModelSerializer):
    class Meta:
        model = AreaGuide
        fields = '__all__'

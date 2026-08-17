from rest_framework import serializers
from .models import DonorProfile, BloodRequest, SocialPost, Hospital, FakeAccountFlag, AdminAction

class HospitalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hospital
        fields = '__all__'

class DonorProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    class Meta:
        model = DonorProfile
        fields = ['id', 'username', 'blood_group', 'district', 'phone_number', 'last_donation_date', 'is_verified', 'latitude', 'longitude']

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

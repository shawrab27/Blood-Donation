# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework import serializers
from .models import (
    Hospital, DonorProfile, BloodRequest, SocialPost, PostReaction, Comment, FakeAccountFlag, AdminAction,
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember, AreaGuide,
    DonationHistory, RecentLog, HealthAccessory, Certificate,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep,
    Product, ProductImage
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

def _is_unlocked_incomplete_user(instance):
    if not instance or getattr(instance, 'is_profile_complete', False):
        return False
    if not (getattr(instance, 'blood_group', None) and instance.blood_group.strip()):
        return True
    if getattr(instance, 'auth_provider', '') == 'google' or bool(getattr(instance, 'google_uid', None)):
        return True
    user = getattr(instance, 'user', None)
    if user:
        username = (getattr(user, 'username', '') or '').lower()
        email = (getattr(user, 'email', '') or '').lower()
        if 'google' in username or email.endswith('@gmail.com'):
            return True
    return False


class DonorProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    password = serializers.CharField(write_only=True, required=False)
    blood_group = serializers.CharField(max_length=5, required=False, allow_blank=True, default='')
    donation_history = DonationHistorySerializer(many=True, read_only=True)
    recent_logs = RecentLogSerializer(many=True, read_only=True)
    global_rank = serializers.IntegerField(read_only=True)
    badge = serializers.CharField(read_only=True)
    days_until_eligible = serializers.IntegerField(read_only=True)
    missing_fields = serializers.SerializerMethodField()
    donor_title = serializers.CharField(read_only=True)
    position_display = serializers.CharField(read_only=True)

    def get_missing_fields(self, obj):
        _, missing = obj.check_is_complete()
        return missing

    def create(self, validated_data):
        validated_data.pop('password', None)
        return super().create(validated_data)

    def validate(self, attrs):
        # USER RULE: blood_group is editable until registration complete, then locked
        if self.instance and self.instance.blood_group and self.instance.blood_group.strip():
            if 'blood_group' in attrs:
                new_bg = (attrs['blood_group'] or '').strip().upper()
                old_bg = self.instance.blood_group.strip().upper()
                if new_bg and new_bg != old_bg:
                    if not _is_unlocked_incomplete_user(self.instance):
                        request = self.context.get('request')
                        if not (request and request.user and request.user.is_staff):
                            raise serializers.ValidationError({
                                'blood_group': 'Blood group is permanently locked once registration is complete.'
                            })
        return super().validate(attrs)

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        # Silently ignore read-only / privileged fields from client
        validated_data.pop('is_verified', None)
        validated_data.pop('is_profile_complete', None)
        if password and instance.user:
            instance.user.set_password(password)
            instance.user.save()
        return super().update(instance, validated_data)

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        ret.pop('password', None)
        return ret

    class Meta:
        model = DonorProfile
        fields = [
            'id', 'username', 'password', 'first_name', 'last_name', 'email', 'blood_group', 
            'district', 'phone_number', 'nid_hash', 'last_donation_date', 'days_until_eligible', 'is_verified', 
            'is_profile_complete', 'is_available', 'email_verified', 'latitude', 'longitude', 'bio', 'institute', 'institution', 'upazila_linked', 'address', 
            'total_bags_donated', 'profile_picture', 'manual_rank_override', 'donation_history', 
            'recent_logs', 'global_rank', 'badge', 'donor_title', 'occupation', 'position_display', 'registration_complete', 'google_display_name', 'google_photo_url', 'auth_provider',
            'is_searchable', 'user_intent', 'missing_fields', 'alert_pause_until', 'emergency_alerts_paused_until',
            'public_profile', 'show_contact', 'notifications_enabled', 'emergency_alerts_enabled',
            'weight_kg', 'show_in_rankings'
        ]

    def validate_bio(self, value):
        if value and len(value) > 120:
            raise serializers.ValidationError("Bio must be 120 characters or fewer.")
        return value

    def validate_weight_kg(self, value):
        if value is not None:
            if value < 30 or value > 300:
                raise serializers.ValidationError("Weight must be between 30kg and 300kg.")
        return value

    def validate_last_donation_date(self, value):
        if value:
            from datetime import date
            if value > date.today():
                raise serializers.ValidationError("Last donation date cannot be in the future.")
        return value

    def validate_phone_number(self, value):
        if not value:
            return value
        from api.phone_utils import normalize_phone_number, get_phone_variants, is_valid_phone
        canonical = normalize_phone_number(value) if is_valid_phone(value) else str(value).strip()
        variants = get_phone_variants(canonical) if is_valid_phone(value) else {canonical}
        qs = DonorProfile.objects.filter(phone_number__in=variants)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("An account with this phone number is already registered.")
        return canonical

    def validate_blood_group(self, value):
        if self.instance and self.instance.blood_group and self.instance.blood_group.strip():
            if value and self.instance.blood_group.strip() != value.strip():
                if not _is_unlocked_incomplete_user(self.instance):
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

    def validate(self, attrs):
        request = self.context.get('request')
        is_staff = request and request.user and request.user.is_staff
        if not is_staff:
            # G2 (b): Silently ignore is_verified on client submit
            attrs.pop('is_verified', None)
            if self.instance:
                admin_locked_fields = ['is_suspended', 'manual_rank_override', 'total_bags_donated']
                for field in admin_locked_fields:
                    if field in attrs and getattr(self.instance, field) != attrs[field]:
                        raise serializers.ValidationError({field: f"Only administrators can modify {field}."})
        return attrs

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        is_owner = request and request.user and request.user.is_authenticated and (request.user.id == instance.user_id or request.user.is_staff)
        if not is_owner:
            # Defensive sanitization for any non-owner representation:
            # Strictly remove PII, exact/fuzzed coordinates, weight, email, and internal tokens
            for field in [
                'phone_number', 'nid_hash', 'latitude', 'longitude', 'weight_kg', 
                'address', 'email', 'fcm_token', 'public_lat', 'public_lng', 'password'
            ]:
                ret.pop(field, None)
        return ret


class PublicDonorProfileSerializer(serializers.ModelSerializer):
    """
    Sanitized public donor profile serializer (Gap #13 Security Hotfix).
    Exposes ONLY safe public attributes: id, name, photo, bio, blood_group, tier, rank, bags, rating_avg, rating_count.
    Strictly removes and never serializes phone_number, nid_hash, latitude, longitude,
    public_lat, public_lng, weight_kg, email, address, or medical data for non-owners.
    """
    name = serializers.SerializerMethodField()
    photo = serializers.SerializerMethodField()
    tier = serializers.CharField(source='badge', read_only=True)
    rank = serializers.IntegerField(source='global_rank', read_only=True)
    bags = serializers.IntegerField(source='total_bags_donated', read_only=True)
    rating_avg = serializers.FloatField(read_only=True)
    rating_count = serializers.IntegerField(read_only=True)
    donor_title = serializers.CharField(read_only=True)
    occupation = serializers.CharField(read_only=True)
    position_display = serializers.CharField(read_only=True)

    class Meta:
        model = DonorProfile
        fields = [
            'id',
            'name',
            'photo',
            'bio',
            'blood_group',
            'tier',
            'rank',
            'bags',
            'rating_avg',
            'rating_count',
            'donor_title',
            'occupation',
            'position_display',
        ]

    def get_name(self, obj):
        full_name = f"{obj.user.first_name or ''} {obj.user.last_name or ''}".strip()
        return full_name or obj.user.username

    def get_photo(self, obj):
        if obj.profile_picture:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.profile_picture.url)
            return obj.profile_picture.url
        if obj.google_photo_url:
            return obj.google_photo_url
        return None

class BloodRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = BloodRequest
        fields = '__all__'

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        user = request.user if request and hasattr(request, 'user') and request.user.is_authenticated else None
        is_owner = user and (user.is_staff or instance.requester_id == user.id)
        is_accepted_donor = user and instance.acceptances.filter(
            donor__user=user,
            status__in=['ACCEPTED', 'ON_THE_WAY', 'ARRIVED', 'DONATED']
        ).exists()
        if not (is_owner or is_accepted_donor):
            if 'contact_phone' in data:
                data['contact_phone'] = "Hidden until accepted"
            if 'contact_number' in data:
                data['contact_number'] = "Hidden until accepted"
            if instance.patient_name:
                parts = instance.patient_name.strip().split()
                data['patient_name'] = f"{parts[0][0]}. {' '.join(p[0] + '.' for p in parts[1:])}" if parts else "Protected Patient"
            if instance.lat is not None and instance.lng is not None:
                from api.utils.geo import fuzz_coordinates
                data['lat'], data['lng'] = fuzz_coordinates(instance.lat, instance.lng, seed_id=instance.id)
        return data

class CommentSerializer(serializers.ModelSerializer):
    author = serializers.SerializerMethodField()
    author_photo = serializers.SerializerMethodField()
    google_photo_url = serializers.SerializerMethodField()

    class Meta:
        model = Comment
        fields = ['id', 'post', 'user', 'author', 'author_photo', 'google_photo_url', 'text', 'created_at']
        read_only_fields = ['id', 'post', 'user', 'author', 'author_photo', 'google_photo_url', 'created_at']

    def get_author(self, obj):
        full_name = obj.user.get_full_name().strip()
        return full_name if full_name else obj.user.username

    def get_author_photo(self, obj):
        profile = getattr(obj.user, 'donorprofile', None)
        if profile and profile.profile_picture:
            return profile.profile_picture.url
        return None

    def get_google_photo_url(self, obj):
        profile = getattr(obj.user, 'donorprofile', None)
        if profile:
            return profile.google_photo_url
        return None


class SocialPostSerializer(serializers.ModelSerializer):
    text_content = serializers.CharField(required=False, allow_blank=True, default='')
    author_name = serializers.SerializerMethodField()
    author_photo = serializers.SerializerMethodField()
    google_photo_url = serializers.SerializerMethodField()
    author_blood_group = serializers.CharField(source='author.blood_group', read_only=True)
    reactions_count = serializers.IntegerField(source='reactions.count', read_only=True)
    comments_count = serializers.IntegerField(source='comments.count', read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    reposted_by = serializers.SerializerMethodField()
    original_author_name = serializers.SerializerMethodField()
    district_name = serializers.SerializerMethodField()
    division_name = serializers.SerializerMethodField()

    class Meta:
        model = SocialPost
        fields = [
            'id', 'author_name', 'author_photo', 'google_photo_url', 'author_blood_group', 'text_content', 
            'created_at', 'likes_count', 'like_count', 'reactions_count', 'comments_count', 'comment_count',
            'comments', 'original_post', 'reposted_by', 'original_author_name',
            'media', 'kind', 'district', 'district_name', 'division', 'division_name'
        ]
        read_only_fields = [
            'id', 'created_at', 'likes_count', 'like_count', 'reactions_count', 'comments_count', 
            'comment_count', 'comments', 'reposted_by', 'original_author_name', 'author_photo', 
            'google_photo_url', 'district_name', 'division_name'
        ]

    def get_district_name(self, obj):
        return obj.district.name if obj.district else None

    def get_division_name(self, obj):
        return obj.division.name if obj.division else None

    def validate_text_content(self, value):
        text = (value or '').strip()
        if len(text) > 500:
            raise serializers.ValidationError("Post text cannot exceed 500 characters.")
        return text

    def validate_media(self, value):
        if not isinstance(value, list):
            raise serializers.ValidationError("Media must be a list of media objects.")
        if len(value) > 4:
            raise serializers.ValidationError("A post can contain at most 4 images.")
        for item in value:
            if not isinstance(item, dict) or 'url' not in item:
                raise serializers.ValidationError("Each media item must be an object with a 'url' property.")
        return value

    def validate(self, attrs):
        text = (attrs.get('text_content') or '').strip()
        media = attrs.get('media') or []
        original_post = attrs.get('original_post')
        if not text and not media and not original_post:
            raise serializers.ValidationError("Post must contain text or at least one image.")
        return attrs

    def get_author_name(self, obj):
        if obj.author and obj.author.user:
            fn = obj.author.user.get_full_name().strip()
            return fn if fn else obj.author.user.username
        return 'Blood Donor'

    def get_author_photo(self, obj):
        if obj.author and obj.author.profile_picture:
            return obj.author.profile_picture.url
        return None

    def get_google_photo_url(self, obj):
        if obj.author:
            return obj.author.google_photo_url
        return None

    def get_reposted_by(self, obj):
        if obj.original_post:
            if obj.author and obj.author.user:
                fn = obj.author.user.get_full_name().strip()
                return fn if fn else obj.author.user.username
        return None

    def get_original_author_name(self, obj):
        if obj.original_post and obj.original_post.author and obj.original_post.author.user:
            fn = obj.original_post.author.user.get_full_name().strip()
            return fn if fn else obj.original_post.author.user.username
        return None



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
    phone_number = serializers.SerializerMethodField()

    class Meta:
        model = NationalCommunity
        fields = '__all__'

    def get_phone_number(self, obj):
        # Step 7.1: Only shown when verified by admin
        if obj.verified_by_admin:
            return obj.phone_number
        return ""

class MedicalPartnerSerializer(serializers.ModelSerializer):
    class Meta:
        model = MedicalPartner
        fields = '__all__'

class ExecutiveMemberSerializer(serializers.ModelSerializer):
    phone_number = serializers.SerializerMethodField()

    class Meta:
        model = ExecutiveMember
        fields = '__all__'

    def get_phone_number(self, obj):
        # Step 7.1 Decision: Phone returned/shown ONLY when show_contact AND verified_by_admin are both true
        if obj.show_contact and obj.verified_by_admin:
            return obj.phone_number
        return ""


class LocalClubSerializer(serializers.ModelSerializer):
    executive_members = ExecutiveMemberSerializer(many=True, read_only=True)
    division_name = serializers.CharField(source='division.name', read_only=True)
    district_name = serializers.CharField(source='district.name', read_only=True)
    upazila_name = serializers.CharField(source='upazila.name', read_only=True)
    contact_number = serializers.SerializerMethodField()

    class Meta:
        model = LocalClub
        fields = '__all__'

    def get_contact_number(self, obj):
        # Step 7.1 Decision: Phone returned/shown ONLY when show_contact AND verified_by_admin are both true
        if obj.show_contact and obj.verified_by_admin:
            return obj.contact_number
        return ""


class LocalClubRegistrationSerializer(serializers.ModelSerializer):
    """
    Used when a user submits a new club registration.
    Club registration saves the officer number with a required "I agree to publish this number"
    checkbox that sets consent_to_publish; nothing is public until admin verifies.
    """
    agree_to_publish = serializers.BooleanField(write_only=True, required=True)

    class Meta:
        model = LocalClub
        fields = [
            'name', 'established_year', 'slogan', 'description',
            'division', 'district', 'upazila',
            'president_name', 'contact_number', 'cover_photo',
            'agree_to_publish'
        ]

    def validate_agree_to_publish(self, value):
        if not value:
            raise serializers.ValidationError("You must agree to publish this contact number before registering.")
        return value

    def validate_cover_photo(self, value):
        if value:
            if value.size > 5 * 1024 * 1024:
                raise serializers.ValidationError("Image file too large ( > 5mb )")
        return value

    def create(self, validated_data):
        agree = validated_data.pop('agree_to_publish', False)
        validated_data['status'] = LocalClub.STATUS_PENDING
        validated_data['is_verified'] = False
        validated_data['verified_by_admin'] = False
        # Officer/club consent stored; nothing is public until verified_by_admin=True
        validated_data['show_contact'] = agree
        club = super().create(validated_data)
        # Also create or link President ExecutiveMember with consent_to_publish
        ExecutiveMember.objects.create(
            club=club,
            name=club.president_name,
            designation='President',
            phone_number=club.contact_number,
            show_contact=agree,
            consent_to_publish=agree,
            verified_by_admin=False,
        )
        return club


class AreaGuideSerializer(serializers.ModelSerializer):
    class Meta:
        model = AreaGuide
        fields = '__all__'

class HealthAccessorySerializer(serializers.ModelSerializer):
    class Meta:
        model = HealthAccessory
        fields = '__all__'


class UserIdentitySerializer(serializers.Serializer):
    id = serializers.IntegerField(source='id')
    display_name = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    badge = serializers.CharField(read_only=True)
    blood_group = serializers.CharField(read_only=True, default='')

    def get_display_name(self, obj):
        user = getattr(obj, 'user', None)
        if getattr(obj, 'public_profile', False) and user:
            first = user.first_name or getattr(obj, 'google_display_name', '') or "Donor"
            initial = f" {user.last_name[0]}." if user.last_name else ""
            return f"{first}{initial}".strip()
        g_name = getattr(obj, 'google_display_name', '')
        if g_name and getattr(obj, 'public_profile', False):
            return g_name
        return "Anonymous Hero"

    def get_avatar_url(self, obj):
        if getattr(obj, 'public_profile', False):
            pic = getattr(obj, 'profile_picture', None)
            if pic:
                try:
                    return pic.url
                except Exception:
                    pass
            return getattr(obj, 'google_photo_url', None)
        return None


class CertificateSerializer(serializers.ModelSerializer):
    donor_name = serializers.SerializerMethodField()
    blood_group = serializers.SerializerMethodField()
    first_donation_date = serializers.SerializerMethodField()
    last_donation_date = serializers.SerializerMethodField()
    verify_url = serializers.SerializerMethodField()

    class Meta:
        model = Certificate
        fields = [
            'id', 'donor_name', 'blood_group', 'donation_count_snapshot',
            'first_donation_date', 'last_donation_date', 'issued_at',
            'revoked', 'verify_url'
        ]

    def get_donor_name(self, obj):
        u = obj.user
        full = f"{u.first_name} {u.last_name}".strip()
        if full:
            return full
        profile = getattr(u, 'donorprofile', None)
        if profile and profile.google_display_name:
            return profile.google_display_name
        return u.username

    def get_blood_group(self, obj):
        profile = getattr(obj.user, 'donorprofile', None)
        return profile.blood_group if profile else ""

    def get_first_donation_date(self, obj):
        profile = getattr(obj.user, 'donorprofile', None)
        if not profile:
            return None
        hist = profile.donation_history.order_by('date').first()
        if hist:
            return hist.date.isoformat()
        return profile.last_donation_date.isoformat() if profile.last_donation_date else None

    def get_last_donation_date(self, obj):
        profile = getattr(obj.user, 'donorprofile', None)
        return profile.last_donation_date.isoformat() if profile and profile.last_donation_date else None

    def get_verify_url(self, obj):
        return f"/verify/{obj.id}/"


class ProductImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductImage
        fields = ['id', 'image_url', 'public_id', 'display_order', 'created_at']


class ProductSerializer(serializers.ModelSerializer):
    images = ProductImageSerializer(many=True, read_only=True)
    price_range_text = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = [
            'id', 'name', 'tier', 'description',
            'price_min', 'price_max', 'currency', 'price_range_text',
            'external_url', 'store_name', 'is_active', 'is_featured',
            'sort_order', 'is_demo', 'availability_text', 'images',
            'created_at', 'updated_at'
        ]

    def get_price_range_text(self, obj):
        if obj.price_min == obj.price_max:
            return f"৳{int(obj.price_min)}" if obj.currency == 'BDT' else f"{obj.currency} {obj.price_min}"
        return f"৳{int(obj.price_min)} - ৳{int(obj.price_max)}" if obj.currency == 'BDT' else f"{obj.currency} {obj.price_min} - {obj.price_max}"


from django.contrib import admin
from .models import (
    Hospital,
    DonorProfile,
    BloodRequest,
    SocialPost,
    FakeAccountFlag,
    AdminAction,
    Community,
)


class HospitalAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'district', 'address', 'is_referral_center')


class DonorProfileAdmin(admin.ModelAdmin):
    list_display = ('id', 'username', 'blood_group', 'district', 'phone_number', 'is_verified')

    @admin.display(ordering='user__username', description='Username')
    def username(self, obj):
        return obj.user.username


class BloodRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient_name', 'blood_group', 'urgency_level', 'hospital_location', 'contact_number', 'is_active', 'created_at')


class SocialPostAdmin(admin.ModelAdmin):
    list_display = ('id', 'author_username', 'text_content', 'likes_count', 'created_at')

    @admin.display(ordering='author__user__username', description='Author')
    def author_username(self, obj):
        return obj.author.user.username


class FakeAccountFlagAdmin(admin.ModelAdmin):
    list_display = ('id', 'donor_username', 'reason', 'flagged_at', 'resolved')

    @admin.display(ordering='donor__user__username', description='Donor')
    def donor_username(self, obj):
        return obj.donor.user.username


class AdminActionAdmin(admin.ModelAdmin):
    list_display = ('id', 'admin_username', 'action_type', 'target_id', 'timestamp', 'notes')

    @admin.display(ordering='admin_user__username', description='Admin User')
    def admin_username(self, obj):
        return obj.admin_user.username


class CommunityAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'community_type', 'district', 'contact_info')


admin.site.register(Hospital, HospitalAdmin)
admin.site.register(DonorProfile, DonorProfileAdmin)
admin.site.register(BloodRequest, BloodRequestAdmin)
admin.site.register(SocialPost, SocialPostAdmin)
admin.site.register(FakeAccountFlag, FakeAccountFlagAdmin)
admin.site.register(AdminAction, AdminActionAdmin)
admin.site.register(Community, CommunityAdmin)

from django.contrib import admin
from .models import (
    Hospital, DonorProfile, BloodRequest, SocialPost, FakeAccountFlag, AdminAction,
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep
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

class LocalClubAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'division', 'district', 'upazila', 'is_verified')

class ExecutiveMemberAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'club', 'designation')

admin.site.register(Hospital, HospitalAdmin)
admin.site.register(DonorProfile, DonorProfileAdmin)
admin.site.register(BloodRequest, BloodRequestAdmin)
admin.site.register(SocialPost, SocialPostAdmin)
admin.site.register(FakeAccountFlag, FakeAccountFlagAdmin)
admin.site.register(AdminAction, AdminActionAdmin)

admin.site.register(Division)
admin.site.register(District)
admin.site.register(Upazila)
admin.site.register(NationalCommunity)
admin.site.register(MedicalPartner)
admin.site.register(LocalClub, LocalClubAdmin)
admin.site.register(ExecutiveMember, ExecutiveMemberAdmin)

# Health Hub Models
@admin.register(BloodScienceArticle)
class BloodScienceArticleAdmin(admin.ModelAdmin):
    list_display = ('title', 'order')
    ordering = ('order',)

@admin.register(CompatibilityRule)
class CompatibilityRuleAdmin(admin.ModelAdmin):
    list_display = ('blood_group', 'can_give_to', 'can_receive_from')

@admin.register(DonationGuideSection)
class DonationGuideSectionAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'order')
    list_filter = ('category',)
    ordering = ('category', 'order')

@admin.register(EmergencyContact)
class EmergencyContactAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone_number', 'is_24_hours')

@admin.register(RecoveryTimelineStep)
class RecoveryTimelineStepAdmin(admin.ModelAdmin):
    list_display = ('hour_mark', 'title')
    ordering = ('hour_mark',)

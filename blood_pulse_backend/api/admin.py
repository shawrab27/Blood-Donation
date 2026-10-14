# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.contrib import admin
from .models import (
    Hospital, DonorProfile, BloodRequest, SocialPost, FakeAccountFlag, AdminAction,
    Division, District, Upazila, NationalCommunity, MedicalPartner, LocalClub, ExecutiveMember,
    BloodScienceArticle, CompatibilityRule, DonationGuideSection, EmergencyContact, RecoveryTimelineStep, HealthAccessory,
    BloodGroupChangeRequest, DonorReview, XPEvent
)

class HospitalAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'district', 'address', 'is_referral_center')

class DonorProfileAdmin(admin.ModelAdmin):
    list_display = ('id', 'username', 'blood_group', 'district', 'phone_number', 'is_verified')

    @admin.display(ordering='user__username', description='Username')
    def username(self, obj):
        return obj.user.username

class BloodRequestAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'patient_name',
        'blood_group',
        'request_mode',
        'units_received',
        'units_pending',
        'units_needed',
        'status',
        'is_active',
        'created_at',
    )
    list_filter = ('status', 'request_mode', 'blood_group', 'is_active')

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

@admin.register(HealthAccessory)
class HealthAccessoryAdmin(admin.ModelAdmin):
    list_display = ('name_en', 'category', 'is_active', 'display_order', 'price_range_text')
    list_filter = ('category', 'is_active')
    search_fields = ('name_en', 'name_bn')
    list_editable = ('is_active', 'display_order')

from django.utils import timezone
from datetime import timedelta
from api.models import RequestAcceptance

@admin.register(RequestAcceptance)
class RequestAcceptanceAdmin(admin.ModelAdmin):
    list_display = ('id', 'donor', 'status', 'donated_at', 'hours_pending', 'auto_confirmed')
    list_filter = ('status', 'auto_confirmed')
    actions = ['force_confirm_selected']

    def hours_pending(self, obj):
        if obj.status == 'DONATED' and obj.donated_at:
            delta = timezone.now() - obj.donated_at
            return f"{delta.total_seconds() / 3600:.1f}h"
        return "-"
    hours_pending.short_description = "Pending for"

    def force_confirm_selected(self, request, queryset):
        from api.services.journeys import finalize_donation
        count = 0
        for acceptance in queryset.filter(status='DONATED'):
            finalize_donation(acceptance, auto=False)
            count += 1
        self.message_user(request, f"Manually confirmed {count} donation(s).")
    force_confirm_selected.short_description = "Force-confirm selected DONATED entries"

from .models import PasswordResetOTP, BrokerReport, FakeReport
@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
    list_display = ('user', 'created_at', 'expires_at', 'is_used', 'attempts')
    list_filter = ('is_used',)
    readonly_fields = ('otp_hash', 'user', 'created_at', 'expires_at', 'is_used', 'attempts', 'last_sent_at')

    def get_readonly_fields(self, request, obj=None):
        return self.readonly_fields


@admin.register(BrokerReport)
class BrokerReportAdmin(admin.ModelAdmin):
    list_display = ('id', 'target_type', 'request', 'reported_user', 'status', 'reason', 'created_at')
    list_filter = ('target_type', 'status')
    search_fields = ('reason', 'details')


@admin.register(FakeReport)
class FakeReportAdmin(admin.ModelAdmin):
    list_display = ('id', 'request', 'status', 'reason', 'created_at')
    list_filter = ('status',)
    search_fields = ('reason',)


from .models import DonorFeedback
@admin.register(DonorFeedback)
class DonorFeedbackAdmin(admin.ModelAdmin):
    """
    Step 6: Private donor feedback admin queue.
    Requester can NEVER view these records; strictly isolated to staff/administrators.
    Flags serious complaints (RUDE, NEVER_CONTACTED) for Trust & Fraud queue review.
    """
    list_display = ('id', 'request_id', 'donor_username', 'requester_username', 'stars', 'tags_display', 'created_at')
    list_filter = ('stars', 'created_at')
    search_fields = ('request__patient_name', 'donor__user__username', 'request__requester__username')
    readonly_fields = ('request', 'donor', 'stars', 'tags', 'created_at')

    @admin.display(ordering='donor__user__username', description='Donor')
    def donor_username(self, obj):
        return obj.donor.user.username

    @admin.display(ordering='request__requester__username', description='Requester')
    def requester_username(self, obj):
        return obj.request.requester.username if obj.request.requester else "Anonymous"

    @admin.display(description='Tags')
    def tags_display(self, obj):
        return ", ".join(obj.tags) if isinstance(obj.tags, list) else str(obj.tags)


from .models import Product, ProductImage

class ProductImageInline(admin.TabularInline):
    model = ProductImage
    extra = 1
    fields = ('image_url', 'public_id', 'display_order')


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    inlines = [ProductImageInline]
    list_display = (
        'id', 'name', 'tier', 'store_name', 'price_min',
        'price_max', 'currency', 'is_active', 'is_featured',
        'sort_order', 'is_demo', 'created_at'
    )
    list_editable = ('price_min', 'price_max', 'is_active', 'is_featured', 'sort_order')
    list_filter = ('tier', 'is_active', 'is_featured', 'is_demo')
    search_fields = ('name', 'description', 'store_name')
    ordering = ('sort_order', '-created_at')

    def delete_model(self, request, obj):
        # Clean up images
        for img in obj.images.all():
            if img.public_id and not obj.is_demo:
                try:
                    import cloudinary.uploader
                    cloudinary.uploader.destroy(img.public_id)
                except Exception:
                    pass
        super().delete_model(request, obj)


@admin.register(BloodGroupChangeRequest)
class BloodGroupChangeRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'current_group', 'requested_group', 'status', 'created_at', 'reviewed_by')
    list_filter = ('status', 'requested_group')
    search_fields = ('user__username', 'reason', 'lab_name')
    readonly_fields = ('created_at', 'reviewed_at')


@admin.register(DonorReview)
class DonorReviewAdmin(admin.ModelAdmin):
    list_display = ('id', 'reviewer', 'donor', 'stars', 'tag', 'created_at')
    list_filter = ('stars',)
    search_fields = ('reviewer__username', 'donor__user__username', 'comment')
    readonly_fields = ('created_at',)


@admin.register(XPEvent)
class XPEventAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'event_type', 'points', 'ref_type', 'ref_id', 'created_at')
    list_filter = ('event_type',)
    search_fields = ('user__username', 'ref_id')
    readonly_fields = ('created_at',)



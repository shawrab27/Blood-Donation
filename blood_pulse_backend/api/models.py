from django.db import models
from django.contrib.auth.models import User

class Hospital(models.Model):
    name = models.CharField(max_length=200)
    district = models.CharField(max_length=100)
    address = models.TextField()
    is_referral_center = models.BooleanField(default=False)
    
    def __str__(self):
        return self.name

class DonorProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    blood_group = models.CharField(max_length=5)
    district = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20, unique=True)
    nid_hash = models.CharField(max_length=64, unique=True, null=True, blank=True)
    last_donation_date = models.DateField(null=True, blank=True)
    is_verified = models.BooleanField(default=False)
    
    # Profile Extensions
    bio = models.TextField(blank=True, null=True, help_text="User's biography or story.")
    institute = models.CharField(max_length=200, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    total_bags_donated = models.IntegerField(default=0)
    profile_picture = models.ImageField(upload_to='profile_pictures/', null=True, blank=True)
    manual_rank_override = models.CharField(max_length=50, blank=True, null=True, help_text="Admin override for badge (e.g. Gold, Platinum).")
    
    # Live Geospatial Location
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    
    @property
    def global_rank(self):
        # Count how many donors have more bags donated
        return DonorProfile.objects.filter(total_bags_donated__gt=self.total_bags_donated).count() + 1
        
    @property
    def badge(self):
        if self.manual_rank_override:
            return self.manual_rank_override
        rank = self.global_rank
        if rank == 1: return "Gold Donor"
        if rank == 2: return "Platinum Donor"
        if rank == 3: return "Bronze Donor"
        return "Green Donor"

    def __str__(self):
        return f"{self.user.username} ({self.blood_group})"

class BloodRequest(models.Model):
    patient_name = models.CharField(max_length=200)
    blood_group = models.CharField(max_length=5)
    urgency_level = models.CharField(max_length=50)
    hospital_location = models.CharField(max_length=300)
    contact_number = models.CharField(max_length=20)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.blood_group} needed at {self.hospital_location}"

class DonationHistory(models.Model):
    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='donation_history')
    date = models.DateField()
    location = models.CharField(max_length=200)
    bags_donated = models.IntegerField(default=1)
    notes = models.TextField(blank=True, null=True)
    
    def __str__(self):
        return f"{self.donor.user.username} - {self.bags_donated} bag(s) on {self.date}"

class RecentLog(models.Model):
    LOG_TYPES = (
        ('DONATION', 'Donation'),
        ('REQUEST', 'Request'),
        ('VERIFICATION', 'Verification'),
        ('SYSTEM', 'System'),
    )
    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='recent_logs')
    log_type = models.CharField(max_length=20, choices=LOG_TYPES, default='SYSTEM')
    title = models.CharField(max_length=200)
    description = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)
    is_success = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.log_type} log for {self.donor.user.username}"

class SocialPost(models.Model):
    author = models.ForeignKey(DonorProfile, on_delete=models.CASCADE)
    text_content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    likes_count = models.IntegerField(default=0)
    
    def __str__(self):
        return f"Post by {self.author.user.username}"


class FakeAccountFlag(models.Model):
    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE)
    reason = models.CharField(max_length=255)
    flagged_at = models.DateTimeField(auto_now_add=True)
    resolved = models.BooleanField(default=False)

    def __str__(self):
        return f"Flag for {self.donor.user.username}: {self.reason}"


class AdminAction(models.Model):
    admin_user = models.ForeignKey(User, on_delete=models.CASCADE)
    action_type = models.CharField(max_length=100)
    target_id = models.IntegerField()
    timestamp = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True)

    def __str__(self):
        return f"{self.admin_user.username} - {self.action_type}"


class Division(models.Model):
    name = models.CharField(max_length=100, unique=True)
    def __str__(self): return self.name

class District(models.Model):
    division = models.ForeignKey(Division, on_delete=models.CASCADE, related_name='districts')
    name = models.CharField(max_length=100)
    def __str__(self): return self.name

class Upazila(models.Model):
    district = models.ForeignKey(District, on_delete=models.CASCADE, related_name='upazilas')
    name = models.CharField(max_length=100)
    def __str__(self): return self.name

class NationalCommunity(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField()
    active_donors = models.CharField(max_length=50, default="0") # e.g. "125K+"
    logo = models.ImageField(upload_to='community_logos/', null=True, blank=True)
    
    def __str__(self): return self.name

class MedicalPartner(models.Model):
    name = models.CharField(max_length=200)
    location = models.CharField(max_length=200)
    accreditation = models.CharField(max_length=200, blank=True)
    image = models.ImageField(upload_to='partner_images/', null=True, blank=True)
    stock_status = models.JSONField(default=dict, blank=True) # e.g. {"A+": "Adequate", "O-": "Low"}
    
    def __str__(self): return self.name

class LocalClub(models.Model):
    name = models.CharField(max_length=200)
    established_year = models.IntegerField(null=True, blank=True)
    slogan = models.CharField(max_length=255, blank=True)
    description = models.TextField()
    
    division = models.ForeignKey(Division, on_delete=models.SET_NULL, null=True)
    district = models.ForeignKey(District, on_delete=models.SET_NULL, null=True)
    upazila = models.ForeignKey(Upazila, on_delete=models.SET_NULL, null=True)
    
    cover_photo = models.ImageField(upload_to='club_covers/', null=True, blank=True)
    
    president_name = models.CharField(max_length=100)
    contact_number = models.CharField(max_length=20)
    president_photo = models.ImageField(upload_to='club_members/', null=True, blank=True)

    total_donors = models.CharField(max_length=50, default="0")
    active_donors = models.CharField(max_length=50, default="0")
    contributions = models.CharField(max_length=50, default="0")

    is_verified = models.BooleanField(default=False)
    
    def __str__(self): return self.name

class ExecutiveMember(models.Model):
    club = models.ForeignKey(LocalClub, on_delete=models.CASCADE, related_name='executive_members')
    name = models.CharField(max_length=100)
    designation = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20)
    photo = models.ImageField(upload_to='club_members/', null=True, blank=True)

    def __str__(self): return f"{self.name} - {self.designation}"


# ── Health Hub Dynamic Models ────────────────────────────────────────────────
class BloodScienceArticle(models.Model):
    title = models.CharField(max_length=200)
    content = models.TextField()
    image = models.ImageField(upload_to='health_hub/science/', null=True, blank=True)
    order = models.IntegerField(default=0)
    
    class Meta:
        ordering = ['order']

    def __str__(self): return self.title


class CompatibilityRule(models.Model):
    blood_group = models.CharField(max_length=5, unique=True)
    can_give_to = models.CharField(max_length=50) # comma separated e.g. "A+, AB+"
    can_receive_from = models.CharField(max_length=50)
    
    def __str__(self): return f"{self.blood_group} Compatibility"


class DonationGuideSection(models.Model):
    CATEGORY_CHOICES = [
        ('eligibility', 'Eligibility Basics'),
        ('journey', 'The Donation Journey'),
        ('myth', 'Myths vs Facts'),
        ('preparation', 'Preparation Tips'),
        ('why_donate', 'Why Donate?'),
    ]
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES)
    title = models.CharField(max_length=200)
    content = models.TextField()
    order = models.IntegerField(default=0)
    
    class Meta:
        ordering = ['category', 'order']

    def __str__(self): return f"[{self.get_category_display()}] {self.title}"


class EmergencyContact(models.Model):
    name = models.CharField(max_length=200)
    phone_number = models.CharField(max_length=50)
    description = models.CharField(max_length=200, blank=True)
    is_24_hours = models.BooleanField(default=True)
    
    def __str__(self): return self.name


class RecoveryTimelineStep(models.Model):
    hour_mark = models.IntegerField() # e.g., 0, 2, 8, 24, 48
    title = models.CharField(max_length=200)
    description = models.TextField()
    activity_guideline = models.CharField(max_length=255, blank=True)
    avoid_list = models.CharField(max_length=255, blank=True) # comma separated
    
    class Meta:
        ordering = ['hour_mark']

    def __str__(self): return f"{self.hour_mark}h: {self.title}"

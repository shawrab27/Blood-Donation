from django.db import models

from django.contrib.auth.models import User



class Hospital(models.Model):

    name = models.CharField(max_length=200)

    name_en = models.CharField(max_length=200, blank=True, default='')

    name_bn = models.CharField(max_length=200, blank=True, default='')

    district = models.CharField(max_length=100)

    division = models.ForeignKey('Division', on_delete=models.SET_NULL, null=True, blank=True, related_name='hospitals')

    upazila = models.ForeignKey('Upazila', on_delete=models.SET_NULL, null=True, blank=True, related_name='hospitals')

    address = models.TextField()

    lat = models.FloatField(null=True, blank=True)

    lng = models.FloatField(null=True, blank=True)

    phone = models.CharField(max_length=50, blank=True, default='')

    is_verified = models.BooleanField(default=False)

    is_referral_center = models.BooleanField(default=False)

    

    def __str__(self):

        return self.name_en or self.name



class DonorProfile(models.Model):

    user = models.OneToOneField(User, on_delete=models.CASCADE)

    blood_group = models.CharField(max_length=5)

    district = models.CharField(max_length=100)

    phone_number = models.CharField(max_length=20, unique=True)

    nid_hash = models.CharField(max_length=64, unique=True, null=True, blank=True)

    last_donation_date = models.DateField(null=True, blank=True)

    is_verified = models.BooleanField(default=False)

    is_profile_complete = models.BooleanField(default=False)

    is_available = models.BooleanField(default=True)

    email_verified = models.BooleanField(default=False)

    

    # Profile Extensions

    bio = models.TextField(blank=True, null=True, help_text="User's biography or story.")

    institute = models.CharField(max_length=200, blank=True, null=True)

    institution = models.ForeignKey('Institution', on_delete=models.SET_NULL, null=True, blank=True, related_name='students')

    upazila_linked = models.ForeignKey('Upazila', on_delete=models.SET_NULL, null=True, blank=True, related_name='donors')

    address = models.TextField(blank=True, null=True)

    total_bags_donated = models.IntegerField(default=0)

    profile_picture = models.ImageField(upload_to='profile_pictures/', null=True, blank=True)

    google_uid = models.CharField(max_length=255, null=True, blank=True, unique=True)
    google_display_name = models.CharField(max_length=255, null=True, blank=True)
    google_photo_url = models.URLField(max_length=500, null=True, blank=True)
    auth_provider = models.CharField(max_length=50, default='password')

    @property
    def registration_complete(self):
        has_name = bool(self.user.first_name)
        has_blood = bool(self.blood_group)
        has_phone = bool(self.phone_number)
        has_district = bool(self.district)
        return has_name and has_blood and has_phone and has_district


    manual_rank_override = models.CharField(max_length=50, blank=True, null=True, help_text="Admin override for badge (e.g. Gold, Platinum).")

    

    # Live Geospatial Location

    latitude = models.FloatField(null=True, blank=True)

    longitude = models.FloatField(null=True, blank=True)

    fcm_token = models.CharField(max_length=255, null=True, blank=True)

    is_suspended = models.BooleanField(default=False)



    # Blood Hub v2 Extensions

    is_searchable = models.BooleanField(default=False, help_text="Opt-in to donor search and map discovery")

    campus = models.CharField(max_length=255, blank=True, default='', help_text="Campus or institutional affiliation")

    fulfilled_count = models.PositiveIntegerField(default=0)

    no_show_count = models.PositiveIntegerField(default=0)

    cancel_count = models.PositiveIntegerField(default=0)

    alert_count = models.PositiveIntegerField(default=0)

    response_count = models.PositiveIntegerField(default=0)

    rating_avg = models.FloatField(default=0.0)

    rating_count = models.PositiveIntegerField(default=0)

    last_active_at = models.DateTimeField(null=True, blank=True)

    last_lat = models.FloatField(null=True, blank=True, help_text="Fuzzed latitude for privacy (~500m)")

    last_lng = models.FloatField(null=True, blank=True, help_text="Fuzzed longitude for privacy (~500m)")

    geohash = models.CharField(max_length=12, blank=True, default='')

    deferral_until = models.DateTimeField(null=True, blank=True)

    alert_pause_until = models.DateTimeField(null=True, blank=True)

    firebase_uid = models.CharField(max_length=128, unique=True, null=True, blank=True)

    

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



    def check_is_complete(self):

        missing = []

        full_name = ""

        if self.user:

            full_name = f"{self.user.first_name or ''} {self.user.last_name or ''}".strip()

        if not full_name:

            missing.append("full_name")



        phone = (self.phone_number or "").strip()

        if not phone or (phone.startswith('+8800000') and len(phone) == 12):

            missing.append("phone_number")



        bg = (self.blood_group or "").strip()

        valid_bgs = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']

        if not bg or bg not in valid_bgs:

            missing.append("blood_group")



        dist = (self.district or "").strip()

        if not dist:

            missing.append("district")



        return len(missing) == 0, missing



    def save(self, *args, **kwargs):

        is_comp, _ = self.check_is_complete()

        self.is_profile_complete = is_comp

        super().save(*args, **kwargs)



    def __str__(self):

        return f"{self.user.username} ({self.blood_group})"



class DeferralRecord(models.Model):

    REASON_CODES = (

        ('MEDICAL', 'Medical Rejection'),

        ('TIMEFRAME', 'Donation Interval Cooldown'),

        ('TRAVEL', 'Travel / Endemic Zone'),

        ('OTHER', 'Other'),

    )

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='deferrals')

    reason = models.CharField(max_length=255)

    reason_code = models.CharField(max_length=20, choices=REASON_CODES, default='MEDICAL')

    starts_at = models.DateTimeField(auto_now_add=True)

    expires_at = models.DateTimeField(null=True, blank=True)

    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)

    is_active = models.BooleanField(default=True)

    appeal_status = models.CharField(max_length=20, default='NONE')

    notes = models.TextField(blank=True, default='')



    def __str__(self):

        return f"Deferral for {self.donor.user.username} until {self.expires_at} ({self.reason_code})"



class BloodRequest(models.Model):

    requester = models.ForeignKey(User, on_delete=models.CASCADE, related_name='blood_requests', null=True, blank=True)

    patient_name = models.CharField(max_length=200)

    blood_group = models.CharField(max_length=5)

    urgency_level = models.CharField(max_length=50, default='CRITICAL_2H')

    hospital_location = models.CharField(max_length=300, blank=True, default='')

    contact_number = models.CharField(max_length=20, blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)

    is_active = models.BooleanField(default=True)



    # Blood Hub v2 Extensions

    mode = models.CharField(max_length=20, default='EMERGENCY') # EMERGENCY, DIRECT

    component = models.CharField(max_length=20, default='WHOLE') # WHOLE, RBC, PLATELETS, PLASMA

    units_needed = models.PositiveIntegerField(default=1)

    urgency = models.CharField(max_length=20, default='CRITICAL_2H') # CRITICAL_2H, URGENT_6H, TODAY_24H, SCHEDULED

    needed_by = models.DateTimeField(null=True, blank=True)

    condition_category = models.CharField(max_length=50, default='OTHER') # SURGERY, ACCIDENT, THALASSEMIA, CANCER, DENGUE, DELIVERY, OTHER

    condition_note = models.CharField(max_length=80, blank=True, default='')

    patient_photo = models.ImageField(upload_to='patient_photos/', null=True, blank=True)

    scope = models.CharField(max_length=20, default='LOCAL') # LOCAL, DISTRICT, DIVISION, NATIONWIDE

    effective_scope = models.CharField(max_length=20, default='LOCAL')

    division = models.ForeignKey('Division', on_delete=models.SET_NULL, null=True, blank=True)

    district = models.CharField(max_length=100, blank=True, default='')

    upazila = models.ForeignKey('Upazila', on_delete=models.SET_NULL, null=True, blank=True)

    hospital = models.ForeignKey(Hospital, on_delete=models.SET_NULL, null=True, blank=True, related_name='blood_requests')

    hospital_name_other = models.CharField(max_length=200, blank=True, default='')

    ward_bed = models.CharField(max_length=100, blank=True, default='')

    attendant_name = models.CharField(max_length=100, blank=True, default='')

    contact_phone = models.CharField(max_length=20, blank=True, default='')

    lat = models.FloatField(null=True, blank=True)

    lng = models.FloatField(null=True, blank=True)

    geohash = models.CharField(max_length=12, blank=True, default='')

    requisition_slip = models.FileField(upload_to='requisition_slips/', null=True, blank=True)

    trust_score = models.IntegerField(default=50)

    trust_band = models.CharField(max_length=20, default='MEDIUM') # LOW, MEDIUM, HIGH

    status = models.CharField(max_length=20, default='ACTIVE') # PENDING_ADMIN, ACTIVE, COVERED, FULFILLED, EXPIRED, CANCELLED, REJECTED

    current_wave = models.PositiveIntegerField(default=1)

    next_wave_at = models.DateTimeField(null=True, blank=True)

    expires_at = models.DateTimeField(null=True, blank=True)

    escalated_to_admin = models.BooleanField(default=False)

    client_request_id = models.UUIDField(null=True, blank=True, unique=True)

    is_drill = models.BooleanField(default=False)



    def __str__(self):

        return f"{self.blood_group} ({self.component}) needed at {self.hospital_name_other or (self.hospital.name if self.hospital else self.hospital_location)}"



class RequestTarget(models.Model):

    STATUS_CHOICES = (

        ('PENDING', 'Pending'),

        ('ACCEPTED', 'Accepted'),

        ('DECLINED', 'Declined'),

        ('EXPIRED', 'Expired'),

    )

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='targets')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='targeted_requests')

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')

    auto_confirmed = models.BooleanField(default=False)

    donated_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    responded_at = models.DateTimeField(null=True, blank=True)



    class Meta:

        unique_together = ('request', 'donor')



class EmergencyNotification(models.Model):

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='notifications')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='emergency_notifications')

    wave = models.PositiveIntegerField(default=1)

    sent_at = models.DateTimeField(auto_now_add=True)

    delivered = models.BooleanField(default=False)

    opened = models.BooleanField(default=False)

    responded = models.BooleanField(default=False)



    class Meta:

        ordering = ['-sent_at']



class RequestAcceptance(models.Model):

    STATUS_CHOICES = (

        ('ACCEPTED', 'Accepted'),

        ('ON_THE_WAY', 'On the Way'),

        ('ARRIVED', 'Arrived at Hospital'),

        ('DONATED', 'Donation Completed'),

        ('FAILED', 'Failed / Cancelled'),

        ('CANCELLED', 'Cancelled by Requester'),

    )

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='acceptances')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='acceptances')

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACCEPTED')
    auto_confirmed = models.BooleanField(default=False)
    donated_at = models.DateTimeField(null=True, blank=True)

    is_standby = models.BooleanField(default=False)

    started_at = models.DateTimeField(auto_now_add=True)

    completed_at = models.DateTimeField(null=True, blank=True)

    cancellation_reason = models.TextField(blank=True, default='')



    # Live Tracking Fields

    donor_lat = models.FloatField(null=True, blank=True)

    donor_lng = models.FloatField(null=True, blank=True)

    last_location_update = models.DateTimeField(null=True, blank=True)

    eta_minutes = models.IntegerField(null=True, blank=True)

    distance_km = models.FloatField(null=True, blank=True)



    class Meta:

        ordering = ['-started_at']



class FakeReport(models.Model):

    STATUS_CHOICES = (

        ('PENDING', 'Pending Review'),

        ('CONFIRMED', 'Confirmed Fake'),

        ('DISMISSED', 'Dismissed / Valid'),

    )

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='fake_reports')

    reporter = models.ForeignKey(User, on_delete=models.CASCADE)

    reason = models.TextField()

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')

    auto_confirmed = models.BooleanField(default=False)

    donated_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)



    class Meta:

        ordering = ['-created_at']



class DonationIssue(models.Model):

    ISSUE_TYPES = (

        ('MEDICAL_REJECTION', 'Medical Rejection (Low Hb, Vein, Vitals)'),

        ('DONOR_NO_SHOW', 'Donor No-Show / Unreachable'),

        ('LOGISTICS_DELAY', 'Logistics / Traffic Delay'),

        ('OTHER', 'Other Issue'),

    )

    acceptance = models.ForeignKey(RequestAcceptance, on_delete=models.CASCADE, related_name='issues')

    reported_by = models.ForeignKey(User, on_delete=models.CASCADE)

    issue_type = models.CharField(max_length=30, choices=ISSUE_TYPES, default='OTHER')

    description = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)



    class Meta:

        ordering = ['-created_at']



    def __str__(self):

        return f"Issue ({self.issue_type}) on Acceptance #{self.acceptance_id}"



class StandbyOffer(models.Model):

    STATUS_CHOICES = (

        ('PENDING', 'Pending Offer'),

        ('ACCEPTED', 'Accepted'),

        ('DECLINED', 'Declined'),

        ('EXPIRED', 'Offer Expired'),

    )

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='standby_offers')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='standby_offers')

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')

    auto_confirmed = models.BooleanField(default=False)

    donated_at = models.DateTimeField(null=True, blank=True)

    offered_at = models.DateTimeField(auto_now_add=True)

    expires_at = models.DateTimeField()

    responded_at = models.DateTimeField(null=True, blank=True)



    class Meta:

        ordering = ['-offered_at']



    def __str__(self):

        return f"Standby Offer to {self.donor.user.username} for Request #{self.request_id} ({self.status})"



class EmailOTP(models.Model):

    email = models.EmailField()

    otp_hash = models.CharField(max_length=64) # HMAC-SHA256 of 6-digit code

    created_at = models.DateTimeField(auto_now_add=True)

    expires_at = models.DateTimeField()

    attempts = models.PositiveIntegerField(default=0)

    is_used = models.BooleanField(default=False)



    class Meta:

        ordering = ['-created_at']



    def is_locked(self):

        return self.attempts >= 5



    def __str__(self):

        return f"OTP for {self.email} (Used: {self.is_used}, Locked: {self.is_locked()})"



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

    original_post = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='reposts')

    

    def __str__(self):

        return f"Post by {self.author.user.username}"





class PostReaction(models.Model):

    post = models.ForeignKey(SocialPost, on_delete=models.CASCADE, related_name='reactions')

    user = models.ForeignKey(User, on_delete=models.CASCADE)

    created_at = models.DateTimeField(auto_now_add=True)



    class Meta:

        unique_together = ('post', 'user')



    def __str__(self):

        return f"{self.user.username} reacted to Post #{self.post_id}"





class Comment(models.Model):

    post = models.ForeignKey(SocialPost, on_delete=models.CASCADE, related_name='comments')

    user = models.ForeignKey(User, on_delete=models.CASCADE)

    text = models.TextField()

    created_at = models.DateTimeField(auto_now_add=True)



    def __str__(self):

        return f"Comment by {self.user.username} on Post #{self.post_id}"







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

    STATUS_PENDING = 'pending'

    STATUS_APPROVED = 'approved'

    STATUS_REJECTED = 'rejected'

    STATUS_CHOICES = [

        (STATUS_PENDING, 'Pending Review'),

        (STATUS_APPROVED, 'Approved'),

        (STATUS_REJECTED, 'Rejected'),

    ]



    name = models.CharField(max_length=200)

    established_year = models.IntegerField(null=True, blank=True)

    slogan = models.CharField(max_length=255, blank=True)

    description = models.TextField()

    

    division = models.ForeignKey(Division, on_delete=models.SET_NULL, null=True, blank=True)

    district = models.ForeignKey(District, on_delete=models.SET_NULL, null=True, blank=True)

    upazila = models.ForeignKey(Upazila, on_delete=models.SET_NULL, null=True, blank=True)

    

    cover_photo = models.ImageField(upload_to='club_covers/', null=True, blank=True)

    

    president_name = models.CharField(max_length=100)

    contact_number = models.CharField(max_length=20)

    president_photo = models.ImageField(upload_to='club_members/', null=True, blank=True)



    total_donors = models.CharField(max_length=50, default="0")

    active_donors = models.CharField(max_length=50, default="0")

    contributions = models.CharField(max_length=50, default="0")



    is_verified = models.BooleanField(default=False)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)

    registered_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='registered_clubs')

    created_at = models.DateTimeField(auto_now_add=True, null=True)

    

    def __str__(self): return self.name



class ExecutiveMember(models.Model):

    club = models.ForeignKey(LocalClub, on_delete=models.CASCADE, related_name='executive_members')

    name = models.CharField(max_length=100)

    designation = models.CharField(max_length=100)

    phone_number = models.CharField(max_length=20)

    photo = models.ImageField(upload_to='club_members/', null=True, blank=True)



    def __str__(self): return f"{self.name} - {self.designation}"





class AreaGuide(models.Model):

    name = models.CharField(max_length=150)

    title = models.CharField(max_length=150, default="Local Blood Guide")

    area_name = models.CharField(max_length=150, default="Uttara, Dhaka")

    division = models.ForeignKey(Division, on_delete=models.SET_NULL, null=True, blank=True)

    district = models.ForeignKey(District, on_delete=models.SET_NULL, null=True, blank=True)

    upazila = models.ForeignKey(Upazila, on_delete=models.SET_NULL, null=True, blank=True)

    phone = models.CharField(max_length=30, default="+8801700000000")

    photo = models.ImageField(upload_to='area_guides/', null=True, blank=True)

    is_active = models.BooleanField(default=True)



    def __str__(self): return f"{self.name} ({self.area_name})"





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





class UserNotificationState(models.Model):

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='notification_state')

    unread_count = models.PositiveIntegerField(default=0)

    updated_at = models.DateTimeField(auto_now=True)



    def __str__(self):

        return f"{self.user.username}: {self.unread_count} unread"



    @classmethod

    def increment_for_user(cls, user, amount=1):

        if not user or not getattr(user, 'is_authenticated', True):

            return 0

        state, _ = cls.objects.get_or_create(user=user)

        state.unread_count += amount

        state.save(update_fields=['unread_count', 'updated_at'])

        return state.unread_count





class EmailVerificationCode(models.Model):

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='email_verification_codes')

    email = models.EmailField()

    code = models.CharField(max_length=6)

    created_at = models.DateTimeField(auto_now_add=True)

    is_used = models.BooleanField(default=False)



    class Meta:

        ordering = ['-created_at']



    def is_valid(self):

        from django.utils import timezone

        import datetime

        return not self.is_used and (timezone.now() - self.created_at) < datetime.timedelta(minutes=15)



    def __str__(self):

        return f"{self.email} - {self.code} (Used: {self.is_used})"









# -----------------------------------------------------------------------------

# PROMPT 9: NATIONAL EMERGENCY & DISASTER RESPONSE

# -----------------------------------------------------------------------------



class NationalEmergencyEvent(models.Model):

    title_en = models.CharField(max_length=200)

    title_bn = models.CharField(max_length=200)

    description_en = models.TextField(blank=True)

    description_bn = models.TextField(blank=True)

    poster_image = models.ImageField(upload_to='emergency_posters/', null=True, blank=True)

    is_active = models.BooleanField(default=True)

    is_verified = models.BooleanField(default=True)

    started_at = models.DateTimeField(auto_now_add=True)

    ended_at = models.DateTimeField(null=True, blank=True)

    donation_interval_days = models.PositiveIntegerField(default=90)

    instructions_en = models.TextField(blank=True)

    instructions_bn = models.TextField(blank=True)



    def __str__(self):

        return self.title_en



class DisasterResponsePoint(models.Model):

    STATUS_CHOICES = [

        ('NEEDED', 'Needed'),

        ('PARTIAL', 'Partial'),

        ('COVERED', 'Covered'),

    ]

    event = models.ForeignKey(NationalEmergencyEvent, on_delete=models.CASCADE, related_name='points')

    name = models.CharField(max_length=200)

    district = models.CharField(max_length=100)

    lat = models.FloatField()

    lng = models.FloatField()

    is_camp = models.BooleanField(default=False)

    target_bags = models.PositiveIntegerField(default=100)

    collected_bags = models.PositiveIntegerField(default=0)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='NEEDED')

    urgent_blood_groups = models.JSONField(default=list)  # e.g., ["O+", "A-"]

    donors_on_the_way = models.PositiveIntegerField(default=0)

    last_updated = models.DateTimeField(auto_now=True)



    def __str__(self):

        return f"{self.name} - {self.district}"



class DonationSlot(models.Model):

    point = models.ForeignKey(DisasterResponsePoint, on_delete=models.CASCADE, related_name='slots')

    time_range = models.CharField(max_length=100)  # e.g., "10:00 AM - 11:00 AM"

    capacity = models.PositiveIntegerField(default=10)

    pledged = models.PositiveIntegerField(default=0)



    def __str__(self):

        return f"{self.point.name} | {self.time_range}"



class DisasterPledge(models.Model):

    STATUS_CHOICES = [

        ('PENDING', 'Pending'),

        ('COMPLETED', 'Completed'),

        ('CANCELLED', 'Cancelled'),

    ]

    event = models.ForeignKey(NationalEmergencyEvent, on_delete=models.CASCADE, related_name='pledges')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='disaster_pledges')

    slot = models.ForeignKey(DonationSlot, on_delete=models.CASCADE, related_name='pledges')

    pledge_code = models.CharField(max_length=10, unique=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')

    auto_confirmed = models.BooleanField(default=False)

    donated_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)



    def __str__(self):

        return f"{self.pledge_code} - {self.donor.user.username}"

class PasswordResetOTP(models.Model):

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_reset_otps')

    otp_hash = models.CharField(max_length=64, default='')

    created_at = models.DateTimeField(auto_now_add=True)

    expires_at = models.DateTimeField()

    is_used = models.BooleanField(default=False)

    last_sent_at = models.DateTimeField(auto_now_add=True, null=True)

    attempts = models.IntegerField(default=0)



class Institution(models.Model):

    INSTITUTION_TYPES = (
        ('school', 'School'),
        ('college', 'College'),
        ('madrasa', 'Madrasa'),
        ('university', 'University'),
        ('technical', 'Technical'),
        ('professional', 'Professional'),
        ('primary', 'Primary'),
        ('other', 'Other'),
    )
    name = models.CharField(max_length=255, db_index=True)
    eiin = models.CharField(max_length=50, null=True, blank=True, db_index=True)
    institution_type = models.CharField(max_length=50, choices=INSTITUTION_TYPES)
    district = models.ForeignKey(District, on_delete=models.SET_NULL, null=True, blank=True, related_name='institutions')
    division_name = models.CharField(max_length=100, null=True, blank=True)
    district_name = models.CharField(max_length=100, null=True, blank=True)
    upazila_name = models.CharField(max_length=100, null=True, blank=True)
    source_file = models.CharField(max_length=100, null=True, blank=True)



    def __str__(self):
        return f"{self.name} ({self.institution_type})"


class InstitutionAlias(models.Model):
    alias = models.CharField(max_length=100, db_index=True)
    eiin = models.CharField(max_length=50, db_index=True)
    institution = models.ForeignKey(
        'Institution',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='aliases',
    )
    source_note = models.CharField(max_length=255, blank=True, default='')

    class Meta:
        db_table = 'api_institution_alias'
        verbose_name_plural = 'Institution Aliases'
        unique_together = ('alias', 'eiin')

    def __str__(self):
        return f"{self.alias} -> {self.eiin}"








# This is an auto-generated Django model module.



# You'll have to do the following manually to clean this up:



#   * Rearrange models' order



#   * Make sure each model has one field with primary_key=True



#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior



#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table



# Feel free to rename the models, but don't rename db_table values or field names.



from django.db import models











class AuditLog(models.Model):



    id = models.BigAutoField(primary_key=True)



    action = models.CharField(max_length=100)



    object_type = models.CharField(max_length=100)



    object_id = models.IntegerField(blank=True, null=True)



    timestamp = models.DateTimeField()



    changes = models.JSONField()



    user = models.ForeignKey(User, models.CASCADE, blank=True, null=True)







    class Meta:



        managed = False



        db_table = 'api_auditlog'











class HealthAccessory(models.Model):



    id = models.BigAutoField(primary_key=True)



    name_en = models.CharField(max_length=255)



    name_bn = models.CharField(max_length=255, blank=True, null=True)



    category = models.CharField(max_length=100)



    description_en = models.TextField()



    description_bn = models.TextField(blank=True, null=True)



    affiliate_url = models.CharField(max_length=500)



    store_name = models.CharField(max_length=255, blank=True, null=True)



    price_range_text = models.CharField(max_length=100, blank=True, null=True)



    is_active = models.BooleanField()



    display_order = models.IntegerField()







    class Meta:



        managed = False



        db_table = 'api_healthaccessory'











class Notification(models.Model):



    id = models.BigAutoField(primary_key=True)



    title = models.CharField(max_length=255)



    body = models.TextField()



    type = models.CharField(max_length=50)



    is_read = models.BooleanField()



    created_at = models.DateTimeField()



    user = models.ForeignKey(User, models.CASCADE)







    class Meta:



        managed = False



        db_table = 'api_notification'











class WaveEscalationLog(models.Model):



    id = models.BigAutoField(primary_key=True)



    from_wave = models.IntegerField()



    to_wave = models.IntegerField()



    triggered_at = models.DateTimeField()



    reason = models.CharField(max_length=255)



    new_radius_km = models.FloatField()



    request = models.ForeignKey('BloodRequest', models.CASCADE)



    triggered_by = models.ForeignKey(User, models.CASCADE, blank=True, null=True)







    class Meta:



        managed = False



        db_table = 'api_waveescalationlog'











class TrustScoreConfig(models.Model):



    id = models.BigAutoField(primary_key=True)



    base_score = models.IntegerField()



    hospital_verified = models.IntegerField()



    prescription_slip = models.IntegerField()



    no_show_penalty = models.IntegerField()

    @classmethod
    def get_solo(cls):
        try:
            obj, _ = cls.objects.get_or_create(
                id=1,
                defaults={
                    'base_score': 50,
                    'hospital_verified': 15,
                    'prescription_slip': 20,
                    'no_show_penalty': 25,
                }
            )
            return obj
        except Exception:
            return cls(
                id=1,
                base_score=50,
                hospital_verified=15,
                prescription_slip=20,
                no_show_penalty=25,
            )







    class Meta:



        managed = False



        db_table = 'api_trustscoreconfig'











class AdminBroadcast(models.Model):



    id = models.BigAutoField(primary_key=True)



    title = models.CharField(max_length=255)



    body = models.TextField()



    audience_filter = models.CharField(max_length=100)



    recipient_count = models.IntegerField()



    sent_at = models.DateTimeField()



    admin_user = models.ForeignKey(User, models.CASCADE, blank=True, null=True)







    class Meta:



        managed = False



        db_table = 'api_adminbroadcast'



# This is an auto-generated Django model module.



# You'll have to do the following manually to clean this up:



#   * Rearrange models' order



#   * Make sure each model has one field with primary_key=True



#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior



#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table



# Feel free to rename the models, but don't rename db_table values or field names.



from django.db import models











class MedicalKnowledgeBase(models.Model):



    id = models.BigAutoField(primary_key=True)



    topic = models.CharField(max_length=255)



    question_en = models.TextField()



    answer_en = models.TextField()



    question_bn = models.TextField(blank=True, null=True)



    answer_bn = models.TextField(blank=True, null=True)



    sources = models.CharField(max_length=500, blank=True, null=True)







    class Meta:



        managed = False



        db_table = 'api_medicalknowledgebase'











class ChatMessage(models.Model):



    id = models.BigAutoField(primary_key=True)



    session_id = models.CharField(max_length=100, blank=True, null=True)



    role = models.CharField(max_length=10)



    content = models.TextField()



    created_at = models.DateTimeField()



    user = models.ForeignKey(User, models.CASCADE)







    class Meta:



        managed = False



        db_table = 'api_chatmessage'













    id = models.BigAutoField(primary_key=True)



    issue_description = models.TextField()



    status = models.CharField(max_length=20)



    created_at = models.DateTimeField()



    updated_at = models.DateTimeField()



    user = models.ForeignKey(User, models.CASCADE)







    class Meta:



        managed = False



        db_table = 'api_supportticket'




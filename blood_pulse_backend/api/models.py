from django.db import models
import uuid
import django.utils.timezone
from django.utils import timezone
from django.core.validators import MaxLengthValidator, MinValueValidator, MaxValueValidator

from django.contrib.auth.models import User
from api.fields import EncryptedBinaryField



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



USER_INTENT_CHOICES = (
    ('DONATE_AND_REQUEST', 'Donate & Request Blood'),
    ('ONLY_REQUEST', 'Only Request Blood'),
)


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

    is_guide = models.BooleanField(default=False)

    

    # Profile Extensions

    bio = models.TextField(
        max_length=120,
        blank=True,
        null=True,
        validators=[MaxLengthValidator(120)],
        help_text="User's biography or story (max 120 chars)."
    )

    weight_kg = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Donor weight in kg (confidential health data, never public)"
    )

    show_in_rankings = models.BooleanField(
        default=True,
        db_default=True,
        help_text="Consent to display in Top Donors and Global Rank leaderboards"
    )

    institute = models.CharField(max_length=200, blank=True, null=True)
    occupation = models.CharField(max_length=100, blank=True, null=True, help_text="User occupation or profession (e.g. Software Engineer, Doctor, Student)")

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
        is_comp, _ = self.check_is_complete()
        return is_comp


    manual_rank_override = models.CharField(max_length=50, blank=True, null=True, help_text="Admin override for badge (e.g. Gold, Platinum).")

    

    # Live Geospatial Location

    latitude = models.FloatField(null=True, blank=True)

    longitude = models.FloatField(null=True, blank=True)

    fcm_token = models.CharField(max_length=255, null=True, blank=True)

    is_suspended = models.BooleanField(default=False)



    # Blood Hub v2 Extensions

    is_searchable = models.BooleanField(default=False, help_text="Opt-in to donor search and map discovery")

    user_intent = models.CharField(
        max_length=30,
        choices=USER_INTENT_CHOICES,
        default='DONATE_AND_REQUEST',
        db_default='DONATE_AND_REQUEST',
        help_text="Registration intent: Donate & Request or Only Request Blood"
    )

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

    public_lat = models.FloatField(null=True, blank=True, help_text="Deterministic fuzzed latitude for privacy (500-1000m)")

    public_lng = models.FloatField(null=True, blank=True, help_text="Deterministic fuzzed longitude for privacy (500-1000m)")

    public_geo_updated_at = models.DateTimeField(null=True, blank=True, help_text="Timestamp when public_lat/public_lng were computed")

    geohash = models.CharField(max_length=12, blank=True, default='')

    deferral_until = models.DateTimeField(null=True, blank=True)

    alert_pause_until = models.DateTimeField(null=True, blank=True)
    emergency_alerts_paused_until = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp until which emergency alerts are paused/snoozed (synced with alert_pause_until)"
    )

    firebase_uid = models.CharField(max_length=128, unique=True, null=True, blank=True)
    public_profile = models.BooleanField(default=False, help_text="Consent to display name on public leaderboard")
    show_contact = models.BooleanField(default=False, help_text="Consent to display contact phone in settings / search")
    notifications_enabled = models.BooleanField(default=True, help_text="Push notifications enabled")
    emergency_alerts_enabled = models.BooleanField(default=True, help_text="Critical blood request alerts enabled")

    @property
    def days_until_eligible(self):
        if not self.last_donation_date:
            return 0
        from datetime import date
        today = date.today()
        if self.last_donation_date > today:
            return 90
        days_since = (today - self.last_donation_date).days
        return max(0, 90 - days_since)

    @property
    def verified_donations_count(self):
        return max(self.total_bags_donated or 0, 0)

    @property
    def global_rank(self):
        count = self.verified_donations_count
        if count == 0:
            return None
        return DonorProfile.objects.filter(total_bags_donated__gt=count).count() + 1

    @property
    def donor_title(self):
        from api.conf import get_donor_title
        return get_donor_title(self.verified_donations_count)

    @property
    def position_display(self):
        title = self.donor_title
        occ = (self.occupation or '').strip() or (self.institute or '').strip()
        if title and occ:
            return f"{title} • {occ}"
        return title or occ or "Blood Donor"

    @property
    def badge(self):
        if self.manual_rank_override:
            return self.manual_rank_override
        if getattr(self.user, 'is_staff', False):
            return "Staff"
        if hasattr(self.user, 'localclub_set') and self.user.localclub_set.exists():
            return "Club Officer"
        count = self.verified_donations_count
        if count >= 10:
            return "Legendary Donor"
        elif count >= 5:
            return "Platinum Donor"
        elif count >= 3:
            return "Gold Donor"
        elif count >= 1:
            return "Verified Donor"
        return "New Donor"



    def check_is_complete(self):
        missing = []
        full_name = ""
        if self.user:
            full_name = f"{self.user.first_name or ''} {self.user.last_name or ''}".strip()
        if not full_name:
            missing.append("full_name")

        phone = (self.phone_number or "").strip()
        placeholder_phones = {'+8801700000000', '01700000000', '+88000000000', '00000000000'}
        is_placeholder = (
            phone in placeholder_phones or
            (phone.startswith('+8800000') and len(phone) == 12) or
            phone.startswith('+8801700000000')
        )
        if not phone or is_placeholder:
            missing.append("phone_number")

        if self.user_intent != 'ONLY_REQUEST':
            bg = (self.blood_group or "").strip()
            valid_bgs = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
            if not bg or bg not in valid_bgs:
                missing.append("blood_group")

        dist_val = getattr(self.district, 'name', self.district)
        dist = str(dist_val or "").strip()
        if not dist:
            missing.append("district")

        return len(missing) == 0, missing

    def __init__(self, *args, **kwargs):
        self._explicit_is_searchable = 'is_searchable' in kwargs
        super().__init__(*args, **kwargs)
        self._was_profile_complete = bool(getattr(self, 'is_profile_complete', False))
        self._initial_alert_pause_until = getattr(self, 'alert_pause_until', None)
        self._initial_emergency_alerts_paused_until = getattr(self, 'emergency_alerts_paused_until', None)

    def save(self, *args, **kwargs):
        was_comp = getattr(self, '_was_profile_complete', False)
        is_comp, _ = self.check_is_complete()
        self.is_profile_complete = is_comp

        if self.user_intent == 'ONLY_REQUEST':
            self.is_searchable = False
        elif is_comp and not was_comp and not getattr(self, '_explicit_is_searchable', False):
            self.is_searchable = True

        lat = self.last_lat if self.last_lat is not None else self.latitude
        lng = self.last_lng if self.last_lng is not None else self.longitude
        geohash_updated = False
        if lat is not None and lng is not None:
            try:
                from api.services.geo import encode_geohash
                self.geohash = encode_geohash(lat, lng, precision=12)
                geohash_updated = True
            except Exception:
                pass

        # Step 4: Deterministic public fuzzed location (HMAC 500-1000m offset)
        real_lat = self.latitude if self.latitude is not None else self.last_lat
        real_lng = self.longitude if self.longitude is not None else self.last_lng
        public_geo_updated = False
        if real_lat is not None and real_lng is not None:
            try:
                from api.services.geo import compute_deterministic_fuzzed_location, should_recompute_fuzzed_location
                from django.utils import timezone
                # Check if public coordinates missing or real location moved beyond threshold
                need_recompute = (
                    self.public_lat is None or
                    self.public_lng is None or
                    getattr(self, '_last_real_lat', None) is None or
                    should_recompute_fuzzed_location(getattr(self, '_last_real_lat'), getattr(self, '_last_real_lng'), real_lat, real_lng)
                )
                if need_recompute:
                    seed_id = self.user_id or self.pk
                    fuzz_lat, fuzz_lng = compute_deterministic_fuzzed_location(real_lat, real_lng, seed_id)
                    self.public_lat = fuzz_lat
                    self.public_lng = fuzz_lng
                    self.public_geo_updated_at = timezone.now()
                    public_geo_updated = True
            except Exception:
                pass

        # Sync alert pause fields
        init_ap = getattr(self, '_initial_alert_pause_until', None)
        init_eap = getattr(self, '_initial_emergency_alerts_paused_until', None)
        if self.alert_pause_until != init_ap:
            self.emergency_alerts_paused_until = self.alert_pause_until
        elif self.emergency_alerts_paused_until != init_eap:
            self.alert_pause_until = self.emergency_alerts_paused_until
        elif self.alert_pause_until != self.emergency_alerts_paused_until:
            if self.alert_pause_until is not None:
                self.emergency_alerts_paused_until = self.alert_pause_until
            else:
                self.alert_pause_until = self.emergency_alerts_paused_until

        update_fields = kwargs.get('update_fields')
        if update_fields is not None:
            update_fields = set(update_fields)
            if 'alert_pause_until' in update_fields:
                update_fields.add('emergency_alerts_paused_until')
            elif 'emergency_alerts_paused_until' in update_fields:
                update_fields.add('alert_pause_until')
            update_fields.add('is_profile_complete')
            if self.user_intent == 'ONLY_REQUEST' or (is_comp and not was_comp and not getattr(self, '_explicit_is_searchable', False)):
                update_fields.add('is_searchable')
            if geohash_updated:
                update_fields.add('geohash')
            if public_geo_updated:
                update_fields.add('public_lat')
                update_fields.add('public_lng')
                update_fields.add('public_geo_updated_at')
            kwargs['update_fields'] = update_fields

        super().save(*args, **kwargs)
        self._was_profile_complete = self.is_profile_complete
        self._explicit_is_searchable = False
        self._last_real_lat = real_lat
        self._last_real_lng = real_lng
        self._initial_alert_pause_until = self.alert_pause_until
        self._initial_emergency_alerts_paused_until = self.emergency_alerts_paused_until



    class Meta:
        indexes = [
            models.Index(fields=['blood_group', 'geohash'], name='idx_donor_bg_geohash'),
            models.Index(fields=['blood_group', 'is_available', 'is_suspended'], name='idx_donor_bg_avail_susp'),
            models.Index(fields=['district', 'blood_group'], name='idx_donor_district_bg'),
            models.Index(fields=['geohash'], name='idx_donor_geohash'),
        ]

    def __str__(self):
        return f"{self.user.username} ({self.blood_group})"


class DonorFeedback(models.Model):
    """
    Step 6: Private donor feedback on requester behavior.
    Only a donor with a donation CONFIRMED by both sides for that request may submit.
    The requester can NEVER read feedback through any endpoint, serializer, notification, or QR page.
    """
    TAG_CHOICES = (
        ('GAVE_TRAVEL_COST', 'Gave travel cost'),
        ('GAVE_FOOD', 'Gave food / refreshments'),
        ('POLITE', 'Polite and respectful'),
        ('RUDE', 'Rude or aggressive'),
        ('NEVER_CONTACTED', 'Never contacted / no-show'),
    )

    request = models.ForeignKey('BloodRequest', on_delete=models.CASCADE, related_name='donor_feedbacks')
    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='submitted_feedbacks')
    stars = models.PositiveSmallIntegerField(help_text="Rating 1 to 5 stars")
    tags = models.JSONField(default=list, blank=True, help_text="List of tag strings: gave_travel_cost, gave_food, polite, rude, never_contacted")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['request', 'donor'], name='unique_request_donor_feedback'),
            models.CheckConstraint(check=models.Q(stars__gte=1, stars__lte=5), name='check_donor_feedback_stars_1_to_5'),
        ]
        indexes = [
            models.Index(fields=['request'], name='idx_feedback_request'),
            models.Index(fields=['donor'], name='idx_feedback_donor'),
        ]

    def clean(self):
        from django.core.exceptions import ValidationError
        if not (1 <= self.stars <= 5):
            raise ValidationError({'stars': "Stars must be between 1 and 5."})

    def __str__(self):
        return f"Feedback for Request #{self.request_id} by Donor #{self.donor_id} ({self.stars} stars)"



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

    units_received = models.PositiveIntegerField(default=0, db_default=0)

    units_pending = models.PositiveIntegerField(default=0, db_default=0)

    REQUEST_MODE_CHOICES = (
        ('SELF', 'Self'),
        ('PROXY', 'Proxy'),
    )

    request_mode = models.CharField(max_length=10, choices=REQUEST_MODE_CHOICES, default='SELF', db_default='SELF')

    closed_at = models.DateTimeField(null=True, blank=True)

    close_reason = models.CharField(max_length=30, blank=True, default='', db_default='')

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

    STATUS_CHOICES = (
        ('DRAFT', 'Draft'),
        ('PENDING_EMAIL_OTP', 'Pending Email OTP'),
        ('OPEN', 'Open'),
        ('ACCEPTED', 'Accepted'),
        ('MATCHED', 'Matched'),
        ('DONOR_ON_THE_WAY', 'Donor On The Way'),
        ('IN_TRANSIT', 'In Transit'),
        ('ARRIVED', 'Arrived'),
        ('DONATED', 'Donated'),
        ('COMPLETED', 'Completed'),
        ('STANDBY_SEARCHING', 'Standby Searching'),
        ('DONOR_CANCELLED', 'Donor Cancelled'),
        ('CLOSED', 'Closed'),
        ('FAILED', 'Failed'),
        ('EXPIRED', 'Expired'),
        ('ACTIVE', 'Active (Legacy)'),
        ('PENDING_ADMIN', 'Pending Admin (Legacy)'),
        ('COVERED', 'Covered (Legacy)'),
        ('FULFILLED', 'Fulfilled (Legacy)'),
        ('CANCELLED', 'Cancelled (Legacy)'),
        ('REJECTED', 'Rejected (Legacy)'),
    )

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT') # DRAFT -> PENDING_EMAIL_OTP -> OPEN -> MATCHED -> IN_TRANSIT -> ARRIVED -> DONATED -> CLOSED | FAILED | EXPIRED

    current_wave = models.PositiveIntegerField(default=1)

    next_wave_at = models.DateTimeField(null=True, blank=True)

    expires_at = models.DateTimeField(null=True, blank=True)

    escalated_to_admin = models.BooleanField(default=False)

    client_request_id = models.UUIDField(null=True, blank=True, unique=True)

    is_drill = models.BooleanField(default=False)



    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(units_received__lte=models.F('units_needed') - models.F('units_pending')),
                name='check_units_received_plus_pending_lte_needed',
            ),
        ]

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



class WaveNotificationLog(models.Model):
    """
    Step 5: Audit and deduplication log for wave notification dispatches.
    Guarantees no donor is notified twice for the same blood request across waves/ticks.
    Never stores donor coordinates.
    """
    STATUS_CHOICES = (
        ('SENT', 'Sent'),
        ('FAILED', 'Failed'),
        ('INVALID_TOKEN', 'Invalid Token'),
        ('SKIPPED', 'Skipped'),
    )

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='wave_notification_logs')
    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='wave_notification_logs')
    wave = models.PositiveIntegerField(default=1)
    sent_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='SENT')

    class Meta:
        ordering = ['-sent_at']
        constraints = [
            models.UniqueConstraint(
                fields=['request', 'donor'],
                name='unique_request_donor_wave_notification',
            ),
        ]



class RequestAcceptance(models.Model):

    STATUS_CHOICES = (

        ('ACCEPTED', 'Accepted'),

        ('ON_THE_WAY', 'On the Way'),

        ('ARRIVED', 'Arrived at Hospital'),

        ('DONATED', 'Donation Completed'),

        ('FAILED', 'Failed / Cancelled'),

        ('CANCELLED', 'Cancelled by Requester'),

    )

    SUPPORT_STATUS_CHOICES = (
        ('CAN_SUPPORT', 'Can Support'),
        ('VOLUNTARY_ONLY', 'Voluntary Only / Charity'),
    )

    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='acceptances')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='acceptances')

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACCEPTED')
    support_status = models.CharField(max_length=30, choices=SUPPORT_STATUS_CHOICES, default='CAN_SUPPORT', db_default='CAN_SUPPORT')
    units_pledged = models.PositiveIntegerField(default=1, db_default=1)
    donor_confirmed_at = models.DateTimeField(null=True, blank=True)
    requester_confirmed_at = models.DateTimeField(null=True, blank=True)
    disputed_at = models.DateTimeField(null=True, blank=True)
    dispute_reason = models.TextField(blank=True, default='', db_default='')
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

    def save(self, *args, **kwargs):
        if self.status in ('COMPLETED', 'CONFIRMED', 'CANCELLED', 'FAILED'):
            self.donor_lat = None
            self.donor_lng = None
            update_fields = kwargs.get('update_fields')
            if update_fields is not None:
                kwargs['update_fields'] = list(set(update_fields) | {'donor_lat', 'donor_lng'})
        super().save(*args, **kwargs)



    class Meta:

        ordering = ['-started_at']
        constraints = [
            models.UniqueConstraint(
                fields=['request', 'donor'],
                name='unique_request_donor_acceptance',
            ),
        ]



class RequestTimelineEvent(models.Model):
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='timeline_events')
    actor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    state = models.CharField(max_length=50)
    note = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def who(self):
        return self.actor

    @property
    def when(self):
        return self.created_at

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f'Request #{self.request_id} -> {self.state} at {self.created_at}'


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


class BrokerReport(models.Model):
    TARGET_TYPE_CHOICES = (
        ('BROKER', 'Suspected Broker / Money Demand'),
        ('REQUEST', 'Fake or Misleading Request'),
        ('DONOR', 'Donor Misconduct'),
    )
    STATUS_CHOICES = (
        ('PENDING', 'Pending Verification'),
        ('CONFIRMED', 'Confirmed Violation'),
        ('DISMISSED', 'Dismissed'),
    )

    request = models.ForeignKey(
        BloodRequest,
        on_delete=models.CASCADE,
        related_name='broker_reports',
        null=True,
        blank=True,
    )
    reported_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='broker_reports_against',
        null=True,
        blank=True,
    )
    reporter = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='submitted_broker_reports',
    )
    target_type = models.CharField(max_length=20, choices=TARGET_TYPE_CHOICES, default='BROKER')
    reason = models.TextField()
    details = models.TextField(blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"BrokerReport #{self.id} ({self.target_type}) [{self.status}]"




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
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='email_otps')
    email = models.EmailField()
    otp_hash = models.CharField(max_length=64) # HMAC-SHA256 of 6-digit code
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    attempts = models.PositiveIntegerField(default=0)
    is_used = models.BooleanField(default=False)
    purpose = models.CharField(max_length=50, default='request_submit')
    last_sent_at = models.DateTimeField(auto_now_add=True, null=True)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, null=True, blank=True, related_name='email_otps')

    class Meta:
        ordering = ['-created_at']

    def is_locked(self):
        return self.attempts >= 5

    def resend_cooldown_passed(self, cooldown_seconds=60):
        if not self.last_sent_at:
            return True
        from django.utils import timezone
        from datetime import timedelta
        return timezone.now() >= self.last_sent_at + timedelta(seconds=cooldown_seconds)

    def __str__(self):
        return f"OTP for {self.email} ({self.purpose}, Used: {self.is_used}, Locked: {self.is_locked()})"


class RequestSubmitToken(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='submit_tokens')
    token_hash = models.CharField(max_length=64, unique=True, db_index=True)
    purpose = models.CharField(max_length=50, default='blood_request_submit')
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    used_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def is_valid(self):
        from django.utils import timezone
        return not self.is_used and timezone.now() <= self.expires_at

    def __str__(self):
        return f"SubmitToken for {self.user.username} ({self.purpose}, used: {self.is_used})"



class DonationMatch(models.Model):

    ROLE_CHOICES = (

        ('PRIMARY', 'Primary Donor'),

        ('STANDBY_1', 'Standby Donor 1'),

        ('STANDBY_2', 'Standby Donor 2'),

    )

    STATUS_CHOICES = (

        ('PENDING', 'Pending Offer'),

        ('ACCEPTED', 'Accepted'),

        ('ON_THE_WAY', 'On The Way'),

        ('ARRIVED', 'Arrived at Hospital'),

        ('DONATED', 'Donated'),

        ('FAILED', 'Failed'),

        ('CANCELLED', 'Cancelled'),

        ('EXPIRED', 'Expired'),

    )



    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='donation_matches')

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='donor_matches')

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACCEPTED')

    SUPPORT_STATUS_CHOICES = (
        ('CAN_SUPPORT', 'Can Support'),
        ('VOLUNTARY_ONLY', 'Voluntary Only / Charity'),
    )
    support_status = models.CharField(max_length=30, choices=SUPPORT_STATUS_CHOICES, default='CAN_SUPPORT', db_default='CAN_SUPPORT')
    units_pledged = models.PositiveIntegerField(default=1, db_default=1)
    donor_confirmed_at = models.DateTimeField(null=True, blank=True)
    requester_confirmed_at = models.DateTimeField(null=True, blank=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    disputed_at = models.DateTimeField(null=True, blank=True)
    dispute_reason = models.TextField(blank=True, default='', db_default='')

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='PRIMARY')

    accepted_at = models.DateTimeField(null=True, blank=True)

    donated_at = models.DateTimeField(null=True, blank=True)

    expires_at = models.DateTimeField(null=True, blank=True) # 5-minute standby promo response timer

    chat_room_id = models.CharField(max_length=100, blank=True, default='')

    tracking_room_id = models.CharField(max_length=100, blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)



    class Meta:

        unique_together = ('request', 'donor')

        ordering = ['-created_at']



    def __str__(self):

        return f"Match #{self.id} (Req #{self.request_id} -> {self.donor.user.username}) [{self.role}: {self.status}]"



class DonationReport(models.Model):

    REASON_CHOICES = (

        ('MEDICAL', 'Medical Ineligibility / Screening Failure'),

        ('NO_SHOW', 'Donor / Recipient No Show'),

        ('LOGISTICS', 'Logistics / Transport / Hospital Issue'),

    )



    match = models.ForeignKey(DonationMatch, on_delete=models.CASCADE, related_name='reports')

    reason = models.CharField(max_length=20, choices=REASON_CHOICES)

    note = models.TextField(blank=True, default='')

    reported_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='donation_reports')

    created_at = models.DateTimeField(auto_now_add=True)



    def __str__(self):

        return f"Report on Match #{self.match_id}: {self.reason}"



class ThankYouLetter(models.Model):

    match = models.OneToOneField(DonationMatch, on_delete=models.CASCADE, related_name='thank_you_letter')

    template_key = models.CharField(max_length=50, default='warm_gratitude')

    body = models.TextField()

    sent_at = models.DateTimeField(auto_now_add=True)



    def __str__(self):

        return f"Thank You for Match #{self.match_id}"



class FollowUp(models.Model):

    STATUS_CHOICES = (

        ('PENDING', 'Pending'),

        ('SENT', 'Sent'),

        ('ANSWERED', 'Answered'),

    )

    RESPONSE_CHOICES = (

        ('OK', 'Feeling OK'),

        ('NOT_OK', 'Experiencing Discomfort / Issues'),

    )



    match = models.OneToOneField(DonationMatch, on_delete=models.CASCADE, related_name='follow_up')

    due_at = models.DateTimeField()

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')

    response = models.CharField(max_length=20, choices=RESPONSE_CHOICES, null=True, blank=True)

    notes = models.TextField(blank=True, default='')

    sent_at = models.DateTimeField(null=True, blank=True)

    answered_at = models.DateTimeField(null=True, blank=True)



    def __str__(self):

        return f"FollowUp for Match #{self.match_id} [{self.status}]"




class DonationHistory(models.Model):
    DONATION_TYPE_CHOICES = (
        ('WHOLE', 'Whole Blood'),
        ('PLATELET', 'Platelet'),
        ('PLASMA', 'Plasma'),
        ('RBC', 'Red Blood Cells'),
    )
    DONATION_HOW_CHOICES = (
        ('VOLUNTARY', 'Voluntary'),
        ('EMERGENCY', 'Emergency'),
        ('BLOOD_DRIVE', 'Blood Drive'),
    )
    DONATION_SOURCE_CHOICES = (
        ('self_reported', 'Self Reported'),
        ('verified', 'Verified'),
    )

    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='donation_history')
    date = models.DateField(help_text="Donation date (kept for backward compatibility)")
    donated_at = models.DateField(null=True, blank=True, help_text="Standardized donation date")
    location = models.CharField(max_length=200)
    hospital = models.CharField(max_length=255, blank=True, default='')
    city = models.CharField(max_length=100, blank=True, default='')
    donation_type = models.CharField(max_length=30, choices=DONATION_TYPE_CHOICES, default='WHOLE')
    how = models.CharField(max_length=30, choices=DONATION_HOW_CHOICES, default='VOLUNTARY')
    bags = models.PositiveIntegerField(default=1)
    bags_donated = models.IntegerField(default=1, help_text="Bags count (kept for backward compatibility)")
    volume_ml = models.PositiveIntegerField(default=450)
    linked_request = models.ForeignKey('BloodRequest', on_delete=models.SET_NULL, null=True, blank=True, related_name='donation_histories')
    source = models.CharField(max_length=30, choices=DONATION_SOURCE_CHOICES, default='self_reported')
    verified = models.BooleanField(default=False)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(default=django.utils.timezone.now)

    class Meta:
        ordering = ['-donated_at', '-date', '-id']
        indexes = [
            models.Index(fields=['donor', 'donated_at'], name='idx_dh_donor_donated_at'),
        ]

    def save(self, *args, **kwargs):
        if not self.donated_at and self.date:
            self.donated_at = self.date
        elif not self.date and self.donated_at:
            self.date = self.donated_at
        if self.bags and self.bags != 1 and self.bags_donated == 1:
            self.bags_donated = self.bags
        elif self.bags_donated and self.bags_donated != 1 and self.bags == 1:
            self.bags = self.bags_donated
        elif not self.bags_donated and self.bags:
            self.bags_donated = self.bags
        elif not self.bags and self.bags_donated:
            self.bags = self.bags_donated
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.donor.user.username} - {self.bags} bag(s) on {self.donated_at or self.date}"


class BloodGroupChangeRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('under_review', 'Under Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='blood_group_change_requests')
    current_group = models.CharField(max_length=10)
    requested_group = models.CharField(max_length=10)
    reason = models.TextField(blank=True, default='')
    lab_name = models.CharField(max_length=200, blank=True, default='')
    test_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True, default='')
    consent = models.BooleanField(default=False)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_blood_group_changes')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    # Encrypted private lab report storage (BinaryField via Fernet symmetric cipher)
    report_file_data = EncryptedBinaryField(null=True, blank=True)
    report_file_name = models.CharField(max_length=255, blank=True, default='')
    report_file_content_type = models.CharField(max_length=100, blank=True, default='')
    report_file_size = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['user'],
                condition=models.Q(status__in=['pending', 'under_review']),
                name='unique_open_blood_group_request'
            )
        ]

    def clean(self):
        from django.core.exceptions import ValidationError
        if self.status in ['pending', 'under_review']:
            existing = BloodGroupChangeRequest.objects.filter(
                user=self.user,
                status__in=['pending', 'under_review']
            )
            if self.pk:
                existing = existing.exclude(pk=self.pk)
            if existing.exists():
                raise ValidationError("You already have an open blood group change request under review.")

    def approve(self, admin_user, notes=""):
        from django.utils import timezone
        self.status = 'approved'
        self.reviewed_by = admin_user
        self.reviewed_at = timezone.now()
        if notes:
            self.notes = f"{self.notes}\nAdmin: {notes}".strip()
        # Storage privacy: delete report bytes after admin decision
        self.report_file_data = None
        self.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'notes', 'report_file_data'])

        donor_profile = getattr(self.user, 'donorprofile', None)
        if donor_profile:
            donor_profile.blood_group = self.requested_group
            donor_profile.save(update_fields=['blood_group'])

    def reject(self, admin_user, notes=""):
        from django.utils import timezone
        self.status = 'rejected'
        self.reviewed_by = admin_user
        self.reviewed_at = timezone.now()
        if notes:
            self.notes = f"{self.notes}\nAdmin: {notes}".strip()
        # Storage privacy: delete report bytes after admin decision
        self.report_file_data = None
        self.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'notes', 'report_file_data'])

    def __str__(self):
        return f"ChangeRequest #{self.id} for {self.user.username}: {self.current_group} -> {self.requested_group} [{self.status}]"


class DonorReview(models.Model):
    reviewer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='submitted_donor_reviews')
    donor = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, related_name='donor_reviews')
    blood_request = models.ForeignKey('BloodRequest', on_delete=models.CASCADE, related_name='donor_reviews')
    stars = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Rating 1 to 5 stars"
    )
    tag = models.CharField(max_length=50, blank=True, default='', help_text="Optional review tag (e.g. Punctual, Supportive)")
    comment = models.TextField(
        max_length=200,
        blank=True,
        default='',
        validators=[MaxLengthValidator(200)],
        help_text="Optional comment max 200 characters"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(fields=['blood_request'], name='unique_review_per_blood_request'),
            models.CheckConstraint(check=models.Q(stars__gte=1, stars__lte=5), name='check_donor_review_stars_1_to_5'),
        ]

    def clean(self):
        from django.core.exceptions import ValidationError
        if self.donor and self.donor.user_id == self.reviewer_id:
            raise ValidationError("You cannot review your own donation.")
        
        if self.blood_request and self.blood_request.requester_id != self.reviewer_id:
            raise ValidationError("Only the blood requester can review the donor.")

        if self.blood_request:
            is_fulfilled = self.blood_request.status in ['DONATED', 'FULFILLED', 'COMPLETED', 'CLOSED'] or (
                hasattr(self.blood_request, 'acceptances') and
                self.blood_request.acceptances.filter(donor=self.donor, status__in=['COMPLETED', 'DONATED']).exists()
            ) or (
                hasattr(self.blood_request, 'donation_matches') and
                self.blood_request.donation_matches.filter(donor=self.donor, status='DONATED').exists()
            ) or (
                DonationHistory.objects.filter(donor=self.donor, linked_request=self.blood_request).exists()
            )
            if not is_fulfilled:
                raise ValidationError("Review can only be submitted after a completed donation linked to this request.")

    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)
        self.update_donor_rating_aggregates()

    def update_donor_rating_aggregates(self):
        from django.db.models import Avg, Count
        aggs = DonorReview.objects.filter(donor=self.donor).aggregate(avg=Avg('stars'), count=Count('id'))
        self.donor.rating_avg = round(float(aggs['avg'] or 0.0), 2)
        self.donor.rating_count = aggs['count'] or 0
        self.donor.save(update_fields=['rating_avg', 'rating_count'])

    def __str__(self):
        return f"Review by {self.reviewer.username} for donor {self.donor.user.username} ({self.stars} stars)"


XP_LEVEL_THRESHOLDS = [
    (1, 0),
    (2, 100),
    (3, 300),
    (4, 600),
    (5, 1000),
    (6, 1500),
    (7, 2100),
    (8, 2800),
    (9, 3600),
    (10, 4500),
]


class XPEvent(models.Model):
    EVENT_TYPES = (
        ('donation', 'Blood Donation'),
        ('share_app', 'Share App'),
        ('read_guide', 'Read Guide'),
        ('update_profile', 'Update Profile'),
        ('send_message', 'Send Message'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='xp_events')
    event_type = models.CharField(max_length=50, choices=EVENT_TYPES)
    points = models.IntegerField()
    ref_type = models.CharField(max_length=50, blank=True, default='')
    ref_id = models.CharField(max_length=100, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'event_type', 'ref_type', 'ref_id'],
                name='unique_user_xp_event'
            )
        ]

    def __str__(self):
        return f"XPEvent: {self.user.username} +{self.points} ({self.event_type})"


def calculate_user_xp_and_level(user):
    from django.db.models import Sum
    total_xp = XPEvent.objects.filter(user=user).aggregate(total=Sum('points'))['total'] or 0
    total_xp = max(0, total_xp)

    current_level = 1
    next_level_xp = XP_LEVEL_THRESHOLDS[1][1]
    current_level_min_xp = 0

    for lvl, threshold in XP_LEVEL_THRESHOLDS:
        if total_xp >= threshold:
            current_level = lvl
            current_level_min_xp = threshold
        else:
            next_level_xp = threshold
            break
    else:
        next_level_xp = XP_LEVEL_THRESHOLDS[-1][1]

    if current_level >= XP_LEVEL_THRESHOLDS[-1][0]:
        progress = 1.0
    else:
        span = next_level_xp - current_level_min_xp
        progress = round(min(1.0, max(0.0, (total_xp - current_level_min_xp) / span)), 4) if span > 0 else 1.0

    return {
        'xp': total_xp,
        'level': current_level,
        'next_level_xp': next_level_xp,
        'progress': progress,
    }


def award_verified_donation_xp(donation_history):
    if not donation_history.verified:
        return None
    user = donation_history.donor.user
    ref_id = str(donation_history.id)
    xp_event, created = XPEvent.objects.get_or_create(
        user=user,
        event_type='donation',
        ref_type='DonationHistory',
        ref_id=ref_id,
        defaults={'points': 100}
    )
    return xp_event



class Certificate(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='certificates')
    issued_at = models.DateTimeField(auto_now_add=True)
    donation_count_snapshot = models.PositiveIntegerField(default=1)
    revoked = models.BooleanField(default=False)

    class Meta:
        ordering = ['-issued_at']

    def __str__(self):
        return f"Certificate {self.id} for {self.user.username} ({self.donation_count_snapshot} donations)"



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

    text_content = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)

    likes_count = models.IntegerField(default=0)
    like_count = models.PositiveIntegerField(default=0)
    comment_count = models.PositiveIntegerField(default=0)

    original_post = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='reposts')

    media = models.JSONField(default=list, blank=True)
    kind = models.CharField(max_length=20, default='general', db_index=True)
    division = models.ForeignKey('Division', on_delete=models.SET_NULL, null=True, blank=True, related_name='posts')
    district = models.ForeignKey('District', on_delete=models.SET_NULL, null=True, blank=True, related_name='posts')
    deleted_at = models.DateTimeField(null=True, blank=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['district', '-created_at', '-id'], name='idx_post_dist_created_id'),
            models.Index(fields=['division', '-created_at'], name='idx_post_div_created'),
            models.Index(fields=['kind', '-created_at'], name='idx_post_kind_created'),
            models.Index(fields=['-created_at', '-id'], name='idx_post_created_id'),
        ]

    def __str__(self):

        return f"Post by {self.author.user.username}"


class MediaUploadRecord(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='uploaded_media')
    public_id = models.CharField(max_length=255, unique=True)
    url = models.URLField(max_length=500)
    width = models.IntegerField(default=0)
    height = models.IntegerField(default=0)
    post = models.ForeignKey(SocialPost, on_delete=models.SET_NULL, null=True, blank=True, related_name='media_records')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Media {self.public_id} by {self.user.username}"


class UserLocationState(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='location_state')
    current_district = models.ForeignKey('District', on_delete=models.SET_NULL, null=True, blank=True)
    current_division = models.ForeignKey('Division', on_delete=models.SET_NULL, null=True, blank=True)
    source = models.CharField(max_length=20, default='profile', choices=[('gps', 'GPS'), ('profile', 'Profile'), ('manual', 'Manual')])
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        dist = self.current_district.name if self.current_district else 'None'
        return f"Location for {self.user.username}: {dist} ({self.source})"


class Product(models.Model):
    TIER_CHOICES = [
        (1, 'Tier 1 - Diagnostic & Clinic'),
        (2, 'Tier 2 - Consumables'),
        (3, 'Tier 3 - Parts & Kits'),
        (4, 'Tier 4 - Donor Gear'),
    ]

    id = models.BigAutoField(primary_key=True)
    name = models.CharField(max_length=255)
    tier = models.IntegerField(choices=TIER_CHOICES, default=1)
    description = models.TextField(blank=True, default='')
    price_min = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    price_max = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    currency = models.CharField(max_length=10, default='BDT')
    external_url = models.URLField(max_length=500, blank=True, default='')
    store_name = models.CharField(max_length=255, blank=True, default='')
    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)
    sort_order = models.IntegerField(default=0)
    is_demo = models.BooleanField(default=False)
    availability_text = models.CharField(max_length=100, blank=True, default='Available Online')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['sort_order', '-created_at']
        indexes = [
            models.Index(fields=['is_active', 'tier']),
            models.Index(fields=['sort_order']),
        ]

    def __str__(self):
        return f"{self.name} (Tier {self.tier}) - {self.store_name}"


class ProductImage(models.Model):
    id = models.BigAutoField(primary_key=True)
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='images')
    image_url = models.URLField(max_length=500)
    public_id = models.CharField(max_length=255, blank=True, default='')
    display_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'id']

    def __str__(self):
        return f"Image {self.id} for {self.product.name}"







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
    phone_number = models.CharField(max_length=30, blank=True, default="", help_text="Direct blood contact / hotline")
    verified_by_admin = models.BooleanField(default=False, help_text="Admin approval required before contact display")

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

    # Step 7: Privacy & verification rule
    show_contact = models.BooleanField(default=False, help_text="Consent toggle to show contact publicly")
    verified_by_admin = models.BooleanField(default=False, help_text="Admin approval required before public contact number display")

    def __str__(self): return self.name



class ExecutiveMember(models.Model):
    club = models.ForeignKey(LocalClub, on_delete=models.CASCADE, related_name='executive_members')
    name = models.CharField(max_length=100)
    designation = models.CharField(max_length=100) # President, General Secretary, Treasurer, Vice President
    phone_number = models.CharField(max_length=20)
    photo = models.ImageField(upload_to='club_members/', null=True, blank=True)

    # Step 7: Privacy & verification rule
    show_contact = models.BooleanField(default=False, help_text="Member toggle to show phone number")
    consent_to_publish = models.BooleanField(default=False, help_text="Officer agreement to publish phone number")
    verified_by_admin = models.BooleanField(default=False, help_text="Admin approval required before phone number display")

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


class DailyHydrationLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='hydration_logs')
    date = models.DateField(default=timezone.now)
    glasses = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} - {self.date}: {self.glasses} glasses"


class GuideApplication(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_APPROVED = 'approved'
    STATUS_REJECTED = 'rejected'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending Review'),
        (STATUS_APPROVED, 'Approved'),
        (STATUS_REJECTED, 'Rejected'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='guide_applications')
    division = models.ForeignKey(Division, on_delete=models.SET_NULL, null=True, blank=True)
    district = models.ForeignKey(District, on_delete=models.SET_NULL, null=True, blank=True)
    upazila = models.ForeignKey(Upazila, on_delete=models.SET_NULL, null=True, blank=True)
    area_name = models.CharField(max_length=150, blank=True)
    intro = models.CharField(max_length=200)
    allow_calls = models.BooleanField(default=False)
    proof_photo = models.URLField(max_length=500, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    rejection_reason = models.TextField(blank=True, null=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_guide_applications')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.status} ({self.area_name or self.district})"





class UserNotificationState(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='notification_state')
    unread_count = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username}: {self.unread_count} unread"

    @classmethod
    def get_unread_for_user(cls, user):
        if not user or not getattr(user, 'is_authenticated', True):
            return 0
        from api.models import Notification
        count = Notification.objects.filter(user=user, is_read=False).count()
        state, _ = cls.objects.get_or_create(user=user)
        if state.unread_count != count:
            state.unread_count = count
            state.save(update_fields=['unread_count', 'updated_at'])
        return count

    @classmethod
    def increment_for_user(cls, user, amount=1):
        return cls.get_unread_for_user(user)





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

    title = models.CharField(max_length=200, blank=True, default='')

    title_en = models.CharField(max_length=200, blank=True, default='')

    title_bn = models.CharField(max_length=200, blank=True, default='')

    description_en = models.TextField(blank=True)

    description_bn = models.TextField(blank=True)

    poster_image = models.ImageField(upload_to='emergency_posters/', null=True, blank=True)

    active = models.BooleanField(default=False)

    is_active = models.BooleanField(default=True)

    is_verified = models.BooleanField(default=True)

    approved_by_admin_1 = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='emergency_approvals_1')

    approved_by_admin_2 = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='emergency_approvals_2')

    activated_at = models.DateTimeField(null=True, blank=True)

    started_at = models.DateTimeField(auto_now_add=True)

    ended_at = models.DateTimeField(null=True, blank=True)

    donation_interval_days = models.PositiveIntegerField(default=90)

    instructions_en = models.TextField(blank=True)

    instructions_bn = models.TextField(blank=True)



    def __str__(self):

        return self.title or self.title_en or "National Emergency Event"



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













class SupportTicket(models.Model):
    id = models.BigAutoField(primary_key=True)



    issue_description = models.TextField()



    status = models.CharField(max_length=20)



    created_at = models.DateTimeField()



    updated_at = models.DateTimeField()



    user = models.ForeignKey(User, models.CASCADE, related_name='api_support_tickets')

    class Meta:
        managed = False
        db_table = 'api_supportticket'


class UserDevice(models.Model):
    """
    Tracks registered active and historical user devices for session management,
    instant revocation, and suspicious login notifications (#35).
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='devices')
    device_id = models.CharField(max_length=255, db_index=True)
    device_name = models.CharField(max_length=255, blank=True, default='')
    platform = models.CharField(max_length=50, blank=True, default='android')
    fcm_token = models.CharField(max_length=512, blank=True, null=True, db_index=True)
    fcm_updated_at = models.DateTimeField(null=True, blank=True)
    first_seen = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)
    last_ip_masked = models.CharField(max_length=50, blank=True, default='')
    last_city_approx = models.CharField(max_length=100, blank=True, default='')
    is_revoked = models.BooleanField(default=False)
    is_new = models.BooleanField(default=True)

    class Meta:
        ordering = ['-last_seen']
        unique_together = ('user', 'device_id')

    def __str__(self):
        return f"{self.user.username} - {self.device_name or self.device_id[:8]} ({self.platform})"


class DirectMessage(models.Model):
    """
    Real-time direct messaging between blood requisition participant (requester)
    and accepted donor (#37, #39).
    Supports delivery and read states, voice notes, and reporting.
    """
    STATUS_CHOICES = (
        ('SENT', 'Sent'),
        ('DELIVERED', 'Delivered'),
        ('READ', 'Read'),
    )
    MESSAGE_TYPE_CHOICES = (
        ('TEXT', 'Text Message'),
        ('VOICE', 'Voice Note'),
        ('IMAGE', 'Image'),
    )

    acceptance = models.ForeignKey(
        'RequestAcceptance',
        on_delete=models.CASCADE,
        related_name='chat_messages',
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sent_direct_messages',
    )
    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='received_direct_messages',
    )
    content = models.TextField(blank=True, default='')
    message_type = models.CharField(
        max_length=20,
        choices=MESSAGE_TYPE_CHOICES,
        default='TEXT',
    )
    voice_url = models.URLField(blank=True, null=True, max_length=500)
    voice_duration_seconds = models.PositiveIntegerField(default=0)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='SENT',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    is_reported = models.BooleanField(default=False)
    report_reason = models.CharField(max_length=255, blank=True, default='')

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['acceptance', 'created_at']),
            models.Index(fields=['recipient', 'status']),
        ]

    def __str__(self):
        return f"Msg {self.id} from {self.sender.username} to {self.recipient.username} ({self.status})"




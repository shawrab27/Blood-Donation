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
    phone_number = models.CharField(max_length=20)
    last_donation_date = models.DateField(null=True, blank=True)
    is_verified = models.BooleanField(default=False)
    
    # Live Geospatial Location
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    
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


class Community(models.Model):
    COMMUNITY_TYPES = [
        ('donor_club', 'Donor Club'),
        ('hospital_partner', 'Hospital Partner'),
        ('local_guide', 'Local Guide'),
    ]

    name = models.CharField(max_length=200)
    community_type = models.CharField(max_length=50, choices=COMMUNITY_TYPES)
    district = models.CharField(max_length=100)
    contact_info = models.CharField(max_length=200)

    def __str__(self):
        return f"{self.name} ({self.community_type})"

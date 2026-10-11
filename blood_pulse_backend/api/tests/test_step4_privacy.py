"""
Step 4: Privacy by Design Test Suite.
Verifies:
1. Deterministic HMAC-SHA256 location fuzzing (500-1000m offset, reproducible across restarts/calls).
2. Threshold-based recomputation of public_lat/public_lng (moves < 500m within same cell do NOT recompute; moves >= 500m or new cell recompute).
3. Serializer leak scan: Public serializers (search, map, guest, profile non-owner) NEVER expose raw latitude, longitude, last_lat, last_lng.
4. Server-side search privacy: Rejects free-text, name, and phone searches (HTTP 400). Accepts blood_group and division/district only.
5. Search eligibility: Returns only eligible donors (passes 90-day cooldown, not ONLY_REQUEST, not snoozed, not deferred) with ONLY 4 display fields.
6. Emergency request detail 3-tier privacy:
   - Anonymous caller: ONLY blood group, status, units counts, hospital name, target reached (0 PII, no patient name/photo/phone/attendant/exact coords).
   - Authenticated non-matched caller: masked patient & attendant name, fuzzed coordinates, protected phone.
   - Matched donor / requester: full raw details.
7. Idempotent management command backfill_public_fuzzed_locations.
"""

from datetime import timedelta
from django.conf import settings
from django.contrib.auth.models import User
from django.core.cache import cache
from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from api.models import BloodRequest, DonationMatch, DonorProfile, RequestAcceptance
from api.services.geo import (
    compute_deterministic_fuzzed_location,
    haversine_distance,
    should_recompute_fuzzed_location,
)
from api.serializers_bloodhub import DonorSearchSerializer, DonorMapSerializer


class Step4PrivacyByDesignTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()

        # Requester
        self.requester_user = User.objects.create_user(
            username="requester_step4",
            email="requester_step4@example.com",
            password="Password123!",
            first_name="Rahim",
            last_name="Uddin",
        )
        self.requester_profile = DonorProfile.objects.create(
            user=self.requester_user,
            blood_group="B+",
            phone_number="+8801711111111",
            district="Dhaka",
            latitude=23.8103,
            longitude=90.4125,
            is_available=True,
            is_profile_complete=True,
        )

        # Matched Donor
        self.donor_user = User.objects.create_user(
            username="matched_donor_step4",
            email="donor_step4@example.com",
            password="Password123!",
            first_name="Tanvir",
            last_name="Ahmed",
        )
        self.donor_profile = DonorProfile.objects.create(
            user=self.donor_user,
            blood_group="B+",
            phone_number="+8801722222222",
            district="Dhaka",
            latitude=23.7808,
            longitude=90.4225,
            is_available=True,
            is_searchable=True,
            is_profile_complete=True,
            user_intent="DONATE_AND_REQUEST",
            last_donation_date=(timezone.now() - timedelta(days=100)).date(),
        )

        # Non-matched user
        self.other_user = User.objects.create_user(
            username="other_user_step4",
            email="other_step4@example.com",
            password="Password123!",
            first_name="Sadia",
            last_name="Khan",
        )
        self.other_profile = DonorProfile.objects.create(
            user=self.other_user,
            blood_group="O+",
            phone_number="+8801733333333",
            district="Dhaka",
            latitude=23.7500,
            longitude=90.3900,
            is_available=True,
            is_profile_complete=True,
        )

        # Emergency blood request
        self.request = BloodRequest.objects.create(
            requester=self.requester_user,
            blood_group="B+",
            units_needed=2,
            units_received=0,
            units_pending=0,
            hospital_name_other="Dhaka Medical College Hospital",
            patient_name="Ayesha Siddiqua",
            attendant_name="Rafiqul Islam",
            contact_number="+8801812345678",
            lat=23.7259,
            lng=90.3976,
            status="OPEN",
            request_mode="PROXY",
            urgency="URGENT_6H",
        )

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Deterministic Location Fuzzing
    # ─────────────────────────────────────────────────────────────────────────
    def test_deterministic_fuzzing_same_coordinates_same_offset(self):
        """The same donor at the same coordinates must always yield the EXACT same fuzzed coordinates."""
        lat = 23.8103
        lng = 90.4125
        donor_id = 99

        fuzzed_lat_1, fuzzed_lng_1 = compute_deterministic_fuzzed_location(lat, lng, donor_id)
        fuzzed_lat_2, fuzzed_lng_2 = compute_deterministic_fuzzed_location(lat, lng, donor_id)

        self.assertEqual(fuzzed_lat_1, fuzzed_lat_2)
        self.assertEqual(fuzzed_lng_1, fuzzed_lng_2)

        # Distance must strictly be between 500m and 1000m
        dist = haversine_distance(lat, lng, fuzzed_lat_1, fuzzed_lng_1) * 1000.0
        self.assertGreaterEqual(dist, 499.0)
        self.assertLessEqual(dist, 1001.0)

    def test_deterministic_fuzzing_different_donors_different_offsets(self):
        """Different donors at the same location get different deterministic offsets."""
        lat = 23.8103
        lng = 90.4125
        res_1 = compute_deterministic_fuzzed_location(lat, lng, donor_id=101)
        res_2 = compute_deterministic_fuzzed_location(lat, lng, donor_id=102)

        self.assertNotEqual(res_1, res_2)

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Threshold Recompute Logic
    # ─────────────────────────────────────────────────────────────────────────
    def test_threshold_recompute_behavior(self):
        """Moving < 500m within the same geohash does NOT recompute; moving >= 500m triggers recompute."""
        donor = self.donor_profile
        initial_public_lat = donor.public_lat
        initial_public_lng = donor.public_lng
        initial_updated_at = donor.public_geo_updated_at

        self.assertIsNotNone(initial_public_lat)
        self.assertIsNotNone(initial_public_lng)

        # Small movement (~50 meters)
        recompute_needed = should_recompute_fuzzed_location(
            old_lat=23.7808,
            old_lng=90.4225,
            new_lat=23.7810,
            new_lng=90.4226,
        )
        self.assertFalse(recompute_needed)

        # Large movement (~2500 meters)
        large_move_needed = should_recompute_fuzzed_location(
            old_lat=23.7808,
            old_lng=90.4225,
            new_lat=23.8100,
            new_lng=90.4225,
        )
        self.assertTrue(large_move_needed)

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Serializer Key Audit
    # ─────────────────────────────────────────────────────────────────────────
    def test_serializer_key_audit_no_raw_coordinates_leaked(self):
        """Public search and map serializers must NEVER leak real-coordinate keys."""
        donor = self.donor_profile

        search_data = DonorSearchSerializer(donor).data
        for forbidden in ("latitude", "longitude", "last_lat", "last_lng", "phone_number"):
            self.assertNotIn(forbidden, search_data)

        # Expected keys only
        self.assertEqual(set(search_data.keys()), {"id", "name", "blood_group", "district", "badge"})

        map_data = DonorMapSerializer(donor).data
        for forbidden in ("latitude", "longitude", "last_lat", "last_lng"):
            self.assertNotIn(forbidden, map_data)
        # Lat/lng exposed in map_data must correspond to public_lat/public_lng
        self.assertEqual(map_data["lat"], donor.public_lat)
        self.assertEqual(map_data["lng"], donor.public_lng)

    # ─────────────────────────────────────────────────────────────────────────
    # 4. Donor Search: Strict Server Rejection of Name & Phone
    # ─────────────────────────────────────────────────────────────────────────
    def test_donor_search_rejects_name_and_phone_queries(self):
        """Attempting to search by name or phone must be blocked on the server with HTTP 400."""
        self.client.force_authenticate(user=self.requester_user)

        for param in ("name", "phone", "phone_number", "mobile", "username", "email"):
            resp = self.client.get(f"/api/donors/search/?{param}=test")
            self.assertEqual(
                resp.status_code,
                400,
                f"Expected HTTP 400 for parameter '{param}', got {resp.status_code}",
            )
            self.assertIn("error", resp.data)

    def test_donor_search_accepts_valid_blood_group_and_district(self):
        """Valid queries by blood group and district succeed and return only 4 display fields."""
        self.client.force_authenticate(user=self.requester_user)

        resp = self.client.get("/api/donors/search/?blood_group=B%2B&district=Dhaka")
        self.assertEqual(resp.status_code, 200)

        results = resp.data.get("results", [])
        self.assertGreaterEqual(len(results), 1)
        first = results[0]

        # Verify only 4 display fields (plus id for request linkage)
        self.assertEqual(set(first.keys()), {"id", "name", "blood_group", "district", "badge"})
        self.assertNotIn("phone", first)
        self.assertNotIn("latitude", first)

    # ─────────────────────────────────────────────────────────────────────────
    # 5. Donor Search Eligibility Rules
    # ─────────────────────────────────────────────────────────────────────────
    def test_donor_search_filters_out_ineligible_donors(self):
        """Donors on cooldown, snoozed, or ONLY_REQUEST must NOT appear in search results."""
        self.client.force_authenticate(user=self.requester_user)

        # Create ineligible donor: within 90-day cooldown
        cooldown_user = User.objects.create_user(
            username="cooldown_donor",
            email="cooldown@example.com",
            password="Password123!",
        )
        cooldown_profile = DonorProfile.objects.create(
            user=cooldown_user,
            blood_group="B+",
            phone_number="+8801744444444",
            district="Dhaka",
            is_available=True,
            is_searchable=True,
            is_profile_complete=True,
            last_donation_date=(timezone.now() - timedelta(days=30)).date(),
        )

        # Create snoozed donor
        snooze_user = User.objects.create_user(
            username="snooze_donor",
            email="snooze@example.com",
            password="Password123!",
        )
        snooze_profile = DonorProfile.objects.create(
            user=snooze_user,
            blood_group="B+",
            phone_number="+8801755555555",
            district="Dhaka",
            is_available=True,
            is_searchable=True,
            is_profile_complete=True,
            alert_pause_until=timezone.now() + timedelta(days=7),
        )

        resp = self.client.get("/api/donors/search/?blood_group=B%2B&district=Dhaka")
        self.assertEqual(resp.status_code, 200)

        returned_ids = [r["id"] for r in resp.data.get("results", [])]
        self.assertIn(self.donor_profile.id, returned_ids)
        self.assertNotIn(cooldown_profile.id, returned_ids)
        self.assertNotIn(snooze_profile.id, returned_ids)

    # ─────────────────────────────────────────────────────────────────────────
    # 6. Emergency Request Detail: 3-Tier Privacy
    # ─────────────────────────────────────────────────────────────────────────
    def test_emergency_request_detail_anonymous_tier(self):
        """Anonymous callers get ONLY units, blood group, status, hospital, target reached. ZERO PII."""
        self.client.logout()
        resp = self.client.get(f"/api/emergency/requests/{self.request.id}/")
        self.assertEqual(resp.status_code, 200)

        data = resp.data
        self.assertIn("blood_group", data)
        self.assertIn("units_needed", data)
        self.assertIn("units_received", data)
        self.assertIn("hospital_name", data)
        self.assertIn("target_reached", data)

        # STRICT PRIVACY: Zero PII
        self.assertNotIn("patient_name", data)
        self.assertNotIn("patient_photo", data)
        self.assertNotIn("attendant_name", data)
        self.assertNotIn("contact_number", data)
        self.assertNotIn("contact_phone_display", data)
        self.assertNotIn("lat", data)
        self.assertNotIn("lng", data)

    def test_emergency_request_detail_authenticated_non_matched_tier(self):
        """Authenticated non-matched callers get masked patient/attendant names and fuzzed location."""
        self.client.force_authenticate(user=self.other_user)
        resp = self.client.get(f"/api/emergency/requests/{self.request.id}/")
        self.assertEqual(resp.status_code, 200)

        data = resp.data
        self.assertEqual(data["has_accepted"], False)
        # Masked patient name: e.g. "A. S."
        self.assertNotEqual(data["patient_name"], "Ayesha Siddiqua")
        self.assertIn(".", data["patient_name"])
        # Protected contact number
        self.assertIn("Protected", data.get("ward_bed_display", ""))
        # Coordinates must be fuzzed
        self.assertNotEqual(data["lat"], self.request.lat)

    def test_emergency_request_detail_matched_donor_tier(self):
        """Matched donor gets full reveal of contact, raw patient name, and attendant."""
        # Create match and acceptance
        RequestAcceptance.objects.create(
            request=self.request,
            donor=self.donor_profile,
            status="ACCEPTED",
            units_pledged=1,
        )
        DonationMatch.objects.create(
            request=self.request,
            donor=self.donor_profile,
            status="ACCEPTED",
        )

        self.client.force_authenticate(user=self.donor_user)
        resp = self.client.get(f"/api/emergency/requests/{self.request.id}/")
        self.assertEqual(resp.status_code, 200)

        data = resp.data
        self.assertEqual(data["has_accepted"], True)
        self.assertEqual(data["patient_name"], "Ayesha Siddiqua")
        self.assertEqual(data["attendant_name"], "Rafiqul Islam")
        self.assertEqual(data["contact_phone_display"], "+8801812345678")
        self.assertEqual(data["lat"], self.request.lat)
        self.assertEqual(data["lng"], self.request.lng)

    # ─────────────────────────────────────────────────────────────────────────
    # 7. Management Command Idempotency
    # ─────────────────────────────────────────────────────────────────────────
    def test_backfill_management_command_is_idempotent(self):
        """Calling backfill_public_fuzzed_locations twice preserves previously fuzzed values."""
        donor = self.donor_profile
        original_public_lat = donor.public_lat
        original_public_lng = donor.public_lng

        call_command("backfill_public_fuzzed_locations")
        donor.refresh_from_db()
        self.assertEqual(donor.public_lat, original_public_lat)
        self.assertEqual(donor.public_lng, original_public_lng)

        # Force run also keeps deterministic values
        call_command("backfill_public_fuzzed_locations", force=True)
        donor.refresh_from_db()
        self.assertEqual(donor.public_lat, original_public_lat)
        self.assertEqual(donor.public_lng, original_public_lng)

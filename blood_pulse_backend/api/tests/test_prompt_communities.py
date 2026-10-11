# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from rest_framework.test import APIClient

class CommunitiesIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_clubs_empty_query(self):
        res = self.client.get('/api/local-clubs/')
        self.assertEqual(res.status_code, 200)

    def test_clubs_no_match(self):
        res = self.client.get('/api/local-clubs/', {'search': 'NonExistentClub123'})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.json()), 0)

    def test_hospitals_empty_query(self):
        res = self.client.get('/api/medical-partners/')
        self.assertIn(res.status_code, [200, 400])

    def test_hospitals_no_match(self):
        res = self.client.get('/api/medical-partners/', {'search': 'NonExistentHospital123'})
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.json()), 0)

    def test_national_community_phone_number_exposed(self):
        from api.models import NationalCommunity
        # Unverified national community: phone hidden
        comm_unverified = NationalCommunity.objects.create(
            name="Unverified Society",
            phone_number="+8801700000001",
            description="National blood society",
            verified_by_admin=False,
        )
        # Verified national community: phone displayed
        comm_verified = NationalCommunity.objects.create(
            name="Bangladesh Red Crescent Society",
            phone_number="+8801700000000",
            description="National blood society",
            verified_by_admin=True,
        )
        res = self.client.get('/api/national-communities/')
        self.assertEqual(res.status_code, 200)
        data = res.json()

        item_unv = next((c for c in data if c['name'] == comm_unverified.name), None)
        item_v = next((c for c in data if c['name'] == comm_verified.name), None)

        self.assertIsNotNone(item_unv)
        self.assertIsNotNone(item_v)
        self.assertEqual(item_unv['phone_number'], "")
        self.assertEqual(item_v['phone_number'], "+8801700000000")


    def test_local_club_and_executive_member_privacy_verification(self):
        from api.models import LocalClub, ExecutiveMember, Division, District
        d_dhaka = Division.objects.create(name="Dhaka")
        dist_dhaka = District.objects.create(division=d_dhaka, name="Dhaka")

        d_ctg = Division.objects.create(name="Chittagong")
        dist_ctg = District.objects.create(division=d_ctg, name="Chittagong")

        d_raj = Division.objects.create(name="Rajshahi")
        dist_raj = District.objects.create(division=d_raj, name="Rajshahi")

        # Club 1: verified_by_admin=True, show_contact=True -> contact_number visible
        c1 = LocalClub.objects.create(
            name="Verified Visible Club",
            division=d_dhaka,
            district=dist_dhaka,
            contact_number="+8801711111111",
            show_contact=True,
            verified_by_admin=True,
            is_verified=True,
            status=LocalClub.STATUS_APPROVED,
        )
        # Club 2: verified_by_admin=False -> contact_number masked
        c2 = LocalClub.objects.create(
            name="Unverified Club",
            division=d_ctg,
            district=dist_ctg,
            contact_number="+8801722222222",
            show_contact=True,
            verified_by_admin=False,
            is_verified=True,
            status=LocalClub.STATUS_APPROVED,
        )
        # Club 3: show_contact=False -> contact_number masked
        c3 = LocalClub.objects.create(
            name="Hidden Contact Club",
            division=d_raj,
            district=dist_raj,
            contact_number="+8801733333333",
            show_contact=False,
            verified_by_admin=True,
            is_verified=True,
            status=LocalClub.STATUS_APPROVED,
        )

        # Executive members on c1
        m1 = ExecutiveMember.objects.create(
            club=c1,
            name="Verified President",
            designation="President",
            phone_number="+8801744444444",
            show_contact=True,
            verified_by_admin=True,
        )
        m2 = ExecutiveMember.objects.create(
            club=c1,
            name="Unverified GS",
            designation="GS",
            phone_number="+8801755555555",
            show_contact=True,
            verified_by_admin=False,
        )
        m3 = ExecutiveMember.objects.create(
            club=c1,
            name="Hidden VP",
            designation="VP",
            phone_number="+8801766666666",
            show_contact=False,
            verified_by_admin=True,
        )

        res = self.client.get('/api/local-clubs/')
        self.assertEqual(res.status_code, 200)
        data = res.json()

        item1 = next((c for c in data if c['id'] == c1.id), None)
        item2 = next((c for c in data if c['id'] == c2.id), None)
        item3 = next((c for c in data if c['id'] == c3.id), None)

        self.assertIsNotNone(item1)
        self.assertIsNotNone(item2)
        self.assertIsNotNone(item3)

        self.assertEqual(item1['contact_number'], "+8801711111111")
        self.assertEqual(item2['contact_number'], "")
        self.assertEqual(item3['contact_number'], "")

        # Check executive members serialized in item1
        exec_members = item1.get('executive_members', [])
        im1 = next((m for m in exec_members if m['name'] == m1.name), None)
        im2 = next((m for m in exec_members if m['name'] == m2.name), None)
        im3 = next((m for m in exec_members if m['name'] == m3.name), None)

        self.assertIsNotNone(im1)
        self.assertIsNotNone(im2)
        self.assertIsNotNone(im3)

        self.assertEqual(im1['phone_number'], "+8801744444444")
        self.assertEqual(im2['phone_number'], "")
        self.assertEqual(im3['phone_number'], "")

    def test_club_registration_consent_required(self):
        from api.models import Division, District, LocalClub, ExecutiveMember
        d = Division.objects.create(name="Barishal")
        dist = District.objects.create(division=d, name="Barishal")

        # 1. Missing agree_to_publish fails with 400
        payload_missing = {
            'name': 'New Hope Club',
            'description': 'Active youth community',
            'president_name': 'Dr. Kamal',
            'contact_number': '+8801811223344',
            'division': d.id,
            'district': dist.id,
        }
        res_fail1 = self.client.post('/api/clubs/register/', payload_missing, format='json')
        self.assertEqual(res_fail1.status_code, 400)

        # 2. agree_to_publish=False fails with 400
        payload_false = dict(payload_missing)
        payload_false['agree_to_publish'] = False
        res_fail2 = self.client.post('/api/clubs/register/', payload_false, format='json')
        self.assertEqual(res_fail2.status_code, 400)

        # 3. agree_to_publish=True succeeds with 201; verified_by_admin is False; contact remains hidden
        payload_ok = dict(payload_missing)
        payload_ok['agree_to_publish'] = True
        res_ok = self.client.post('/api/clubs/register/', payload_ok, format='json')
        self.assertEqual(res_ok.status_code, 201)

        club_id = res_ok.json()['club_id']
        club = LocalClub.objects.get(id=club_id)
        self.assertFalse(club.verified_by_admin)
        self.assertTrue(club.show_contact)
        self.assertFalse(club.is_verified)

        exec_pres = ExecutiveMember.objects.filter(club=club, designation='President').first()
        self.assertIsNotNone(exec_pres)
        self.assertTrue(exec_pres.consent_to_publish)
        self.assertFalse(exec_pres.verified_by_admin)

        # In serializer / list response, contact_number is hidden because verified_by_admin=False
        res_list = self.client.get('/api/local-clubs/')
        # Unapproved/unverified clubs are filtered from public list anyway
        item = next((c for c in res_list.json() if c['id'] == club.id), None)
        self.assertIsNone(item)


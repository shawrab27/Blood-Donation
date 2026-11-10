# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from datetime import timedelta
from django.contrib.auth.models import User
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from api.admin import SponsoredCardAdminForm
from api.models import FeatureFlag, SponsoredCard


class SponsoredCardsFeatureTests(TestCase):
    """
    Tests for admin-managed feed sponsored cards:
    - Anonymous rejected (401)
    - FeatureFlag 'sponsored_cards' off or missing returns empty list
    - Active cards inside date window filtering
    - Inactive cards hidden
    - Maximum 10 cards returned without pagination
    - Ordering: priority (descending) then newest (created_at descending)
    - No PII in serialized card response
    - Server-side cache 60s
    - Model & Admin validation: ends_at > starts_at, link must be https, phone must look like phone
    """

    def setUp(self):
        cache.clear()
        self.client = APIClient()

        # Regular authenticated user
        self.user = User.objects.create_user(
            username='01711000001',
            email='user@example.com',
            password='TestPassword123!',
            first_name='Test',
            last_name='User'
        )
        self.now = timezone.now()

    def _enable_flag(self):
        flag, _ = FeatureFlag.objects.get_or_create(name='sponsored_cards')
        flag.enabled = True
        flag.allowed_user_ids = []
        flag.save()
        return flag

    def _disable_flag(self):
        flag, _ = FeatureFlag.objects.get_or_create(name='sponsored_cards')
        flag.enabled = False
        flag.save()
        return flag

    def test_anonymous_rejected(self):
        """Anonymous access to /api/feed/sponsored/ must be rejected with HTTP 401."""
        response = self.client.get('/api/feed/sponsored/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_flag_off_returns_empty(self):
        """When FeatureFlag 'sponsored_cards' is missing or disabled, returns empty list (HTTP 200)."""
        self.client.force_authenticate(user=self.user)

        # 1. Flag missing
        FeatureFlag.objects.filter(name='sponsored_cards').delete()
        SponsoredCard.objects.create(
            title='Card Missing Flag',
            sponsor_name='Sponsor A',
            starts_at=self.now - timedelta(days=1),
            ends_at=self.now + timedelta(days=1),
            is_active=True,
            priority=1,
        )
        res_missing = self.client.get('/api/feed/sponsored/')
        self.assertEqual(res_missing.status_code, status.HTTP_200_OK)
        self.assertEqual(res_missing.json(), [])

        # 2. Flag exists but enabled=False
        cache.clear()
        self._disable_flag()
        res_disabled = self.client.get('/api/feed/sponsored/')
        self.assertEqual(res_disabled.status_code, status.HTTP_200_OK)
        self.assertEqual(res_disabled.json(), [])

    def test_window_filtering(self):
        """Only cards inside the active window (starts_at <= now <= ends_at) are returned."""
        self._enable_flag()
        self.client.force_authenticate(user=self.user)

        # Past card (ended yesterday)
        SponsoredCard.objects.create(
            title='Past Card',
            sponsor_name='Sponsor Past',
            starts_at=self.now - timedelta(days=5),
            ends_at=self.now - timedelta(days=1),
            is_active=True,
            priority=1,
        )
        # Future card (starts tomorrow)
        SponsoredCard.objects.create(
            title='Future Card',
            sponsor_name='Sponsor Future',
            starts_at=self.now + timedelta(days=1),
            ends_at=self.now + timedelta(days=5),
            is_active=True,
            priority=1,
        )
        # Active card
        active_card = SponsoredCard.objects.create(
            title='Current Active Card',
            sponsor_name='Sponsor Active',
            starts_at=self.now - timedelta(hours=2),
            ends_at=self.now + timedelta(hours=2),
            is_active=True,
            priority=10,
        )

        resp = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['id'], active_card.id)
        self.assertEqual(data[0]['title'], 'Current Active Card')

    def test_inactive_hidden(self):
        """Cards with is_active=False within date window must not be returned."""
        self._enable_flag()
        self.client.force_authenticate(user=self.user)

        SponsoredCard.objects.create(
            title='Inactive Inside Window',
            sponsor_name='Sponsor Inactive',
            starts_at=self.now - timedelta(days=1),
            ends_at=self.now + timedelta(days=1),
            is_active=False,
            priority=5,
        )

        resp = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.json(), [])

    def test_max_10(self):
        """At most 10 active cards are returned, without pagination wrapper."""
        self._enable_flag()
        self.client.force_authenticate(user=self.user)

        # Create 15 active cards
        for i in range(15):
            SponsoredCard.objects.create(
                title=f'Card {i}',
                sponsor_name=f'Sponsor {i}',
                starts_at=self.now - timedelta(hours=1),
                ends_at=self.now + timedelta(days=1),
                is_active=True,
                priority=i,
            )

        resp = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertIsInstance(data, list)
        self.assertEqual(len(data), 10)

    def test_ordering(self):
        """Cards are ordered by priority (descending) then newest (created_at descending)."""
        self._enable_flag()
        self.client.force_authenticate(user=self.user)

        card_low = SponsoredCard.objects.create(
            title='Low Priority',
            sponsor_name='Sponsor Low',
            starts_at=self.now - timedelta(hours=1),
            ends_at=self.now + timedelta(days=1),
            is_active=True,
            priority=5,
        )
        card_high_older = SponsoredCard.objects.create(
            title='High Older',
            sponsor_name='Sponsor High',
            starts_at=self.now - timedelta(hours=1),
            ends_at=self.now + timedelta(days=1),
            is_active=True,
            priority=20,
        )
        # Ensure older card has an earlier timestamp
        SponsoredCard.objects.filter(id=card_high_older.id).update(created_at=self.now - timedelta(minutes=10))

        card_high_newer = SponsoredCard.objects.create(
            title='High Newer',
            sponsor_name='Sponsor High',
            starts_at=self.now - timedelta(hours=1),
            ends_at=self.now + timedelta(days=1),
            is_active=True,
            priority=20,
        )
        SponsoredCard.objects.filter(id=card_high_newer.id).update(created_at=self.now - timedelta(minutes=1))

        resp = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        data = resp.json()
        self.assertEqual(len(data), 3)
        # Higher priority first; between equal priority, newer created_at first
        self.assertEqual(data[0]['id'], card_high_newer.id)
        self.assertEqual(data[1]['id'], card_high_older.id)
        self.assertEqual(data[2]['id'], card_low.id)

    def test_no_pii(self):
        """Card responses contain only public sponsor fields and no user PII."""
        self._enable_flag()
        self.client.force_authenticate(user=self.user)

        card = SponsoredCard.objects.create(
            title='Card Public Info',
            short_text='Short description',
            body='Full details body',
            sponsor_name='Evercare Hospital',
            kind=SponsoredCard.KIND_HOSPITAL_UPDATE,
            cta_type=SponsoredCard.CTA_LINK,
            cta_value='https://evercarebd.com',
            starts_at=self.now - timedelta(hours=1),
            ends_at=self.now + timedelta(days=1),
            is_active=True,
            priority=1,
        )

        resp = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        item = resp.json()[0]

        expected_keys = {
            'id', 'title', 'short_text', 'body', 'image', 'sponsor_name',
            'kind', 'cta_type', 'cta_value', 'starts_at', 'ends_at',
            'is_active', 'priority', 'created_at'
        }
        self.assertEqual(set(item.keys()), expected_keys)
        # Ensure forbidden PII terms are nowhere in the keys
        for forbidden in ('user', 'user_id', 'email', 'phone_number', 'nid', 'author', 'requester', 'donor'):
            self.assertNotIn(forbidden, item)

    def test_cache_60s_and_admin_invalidation(self):
        """Server-side cache stores response for 60s and admin save invalidates cache."""
        self._enable_flag()
        self.client.force_authenticate(user=self.user)

        card = SponsoredCard.objects.create(
            title='Cached Card Initial',
            sponsor_name='Sponsor C',
            starts_at=self.now - timedelta(hours=1),
            ends_at=self.now + timedelta(days=1),
            is_active=True,
            priority=1,
        )

        # 1. First fetch populates cache
        resp1 = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp1.json()[0]['title'], 'Cached Card Initial')

        # 2. Direct DB update without invalidating cache
        SponsoredCard.objects.filter(id=card.id).update(title='Cached Card Updated Directly')
        resp_cached = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp_cached.json()[0]['title'], 'Cached Card Initial')

        # 3. Cache clearing / admin invalidation reflects update
        cache.delete('feed_sponsored_cards')
        resp_fresh = self.client.get('/api/feed/sponsored/')
        self.assertEqual(resp_fresh.json()[0]['title'], 'Cached Card Updated Directly')

    def test_admin_validation(self):
        """
        Validates:
        - ends_at must be strictly after starts_at
        - link CTA must start with https://
        - call CTA must look like a phone number
        - none CTA allows empty cta_value
        """
        # 1. ends_at <= starts_at
        bad_dates_card = SponsoredCard(
            title='Bad Dates',
            sponsor_name='Sponsor',
            starts_at=self.now,
            ends_at=self.now - timedelta(hours=1),
            cta_type=SponsoredCard.CTA_NONE,
        )
        with self.assertRaises(ValidationError) as ctx:
            bad_dates_card.clean()
        self.assertIn('ends_at', ctx.exception.message_dict)

        # Form clean also rejects
        form_bad_dates = SponsoredCardAdminForm(data={
            'title': 'Bad Dates',
            'sponsor_name': 'Sponsor',
            'kind': 'hospital_update',
            'cta_type': 'none',
            'starts_at': self.now,
            'ends_at': self.now - timedelta(hours=1),
            'priority': 0,
            'is_active': True,
        })
        self.assertFalse(form_bad_dates.is_valid())
        self.assertIn('ends_at', form_bad_dates.errors)

        # 2. link must be https
        bad_link_card = SponsoredCard(
            title='Bad Link',
            sponsor_name='Sponsor',
            starts_at=self.now,
            ends_at=self.now + timedelta(days=1),
            cta_type=SponsoredCard.CTA_LINK,
            cta_value='http://insecure.example.com',
        )
        with self.assertRaises(ValidationError) as ctx:
            bad_link_card.clean()
        self.assertIn('cta_value', ctx.exception.message_dict)

        # Valid https link passes
        good_link_card = SponsoredCard(
            title='Good Link',
            sponsor_name='Sponsor',
            starts_at=self.now,
            ends_at=self.now + timedelta(days=1),
            cta_type=SponsoredCard.CTA_LINK,
            cta_value='https://secure.example.com',
        )
        good_link_card.clean()  # Does not raise

        # 3. phone must look like phone number
        bad_phone_card = SponsoredCard(
            title='Bad Phone',
            sponsor_name='Sponsor',
            starts_at=self.now,
            ends_at=self.now + timedelta(days=1),
            cta_type=SponsoredCard.CTA_CALL,
            cta_value='call-me-now',
        )
        with self.assertRaises(ValidationError) as ctx:
            bad_phone_card.clean()
        self.assertIn('cta_value', ctx.exception.message_dict)

        # Valid phone passes (+8801712345678 and hotline 16263)
        good_phone_card = SponsoredCard(
            title='Good Phone',
            sponsor_name='Sponsor',
            starts_at=self.now,
            ends_at=self.now + timedelta(days=1),
            cta_type=SponsoredCard.CTA_CALL,
            cta_value='+8801712345678',
        )
        good_phone_card.clean()  # Does not raise

        good_hotline_card = SponsoredCard(
            title='Good Hotline',
            sponsor_name='Sponsor',
            starts_at=self.now,
            ends_at=self.now + timedelta(days=1),
            cta_type=SponsoredCard.CTA_CALL,
            cta_value='16263',
        )
        good_hotline_card.clean()  # Does not raise

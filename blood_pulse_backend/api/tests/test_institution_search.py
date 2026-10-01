from django.test import TestCase
from unittest.mock import patch
from rest_framework.test import APIClient
from rest_framework import status
from api.models import Institution, District, Division


class InstitutionSearchTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.division = Division.objects.create(name='TEST DIVISION')
        self.district = District.objects.create(name='TEST DISTRICT 1', division=self.division)

        self.inst1 = Institution.objects.create(
            name='TEST INSTITUTION 1 ALPHA',
            eiin='999001',
            institution_type='school',
            district=self.district,
            district_name='TEST DISTRICT 1',
            division_name='TEST DIVISION',
            upazila_name='TEST UPAZILA',
            source_file='test.xlsx',
        )
        self.inst2 = Institution.objects.create(
            name='SAMPLE TEST INSTITUTION 2',
            eiin='999002',
            institution_type='college',
            district=self.district,
            district_name='TEST DISTRICT 1',
            division_name='TEST DIVISION',
            upazila_name='TEST UPAZILA',
            source_file='test.xlsx',
        )
        self.inst3 = Institution.objects.create(
            name='TEST INSTITUTION 3 BETA',
            eiin='999003',
            institution_type='university',
            district_name='OTHER DISTRICT',
            division_name='TEST DIVISION',
            source_file='test.xlsx',
        )

    def test_short_and_empty_query_returns_empty_list(self):
        # Empty query
        res = self.client.get('/api/institutions/search/?q=')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json(), [])

        # Single char query
        res = self.client.get('/api/institutions/search/?q=T')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json(), [])

        # Whitespace query
        res = self.client.get('/api/institutions/search/?q=   ')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json(), [])

    def test_prefix_matches_first_then_contains(self):
        # Searching 'TEST' should return inst1 & inst3 first (prefix matches), then inst2 (contains match)
        res = self.client.get('/api/institutions/search/?q=TEST')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 3)

        # First two should start with TEST
        self.assertTrue(data[0]['name'].startswith('TEST'))
        self.assertTrue(data[1]['name'].startswith('TEST'))
        # Third one contains TEST but does not start with it
        self.assertEqual(data[2]['name'], 'SAMPLE TEST INSTITUTION 2')

    def test_case_insensitive_matching(self):
        res = self.client.get('/api/institutions/search/?q=test')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.json()), 3)

    def test_no_email_or_personal_fields_in_response(self):
        res = self.client.get('/api/institutions/search/?q=TEST')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        for item in res.json():
            self.assertNotIn('email', item)
            self.assertNotIn('phone', item)
            self.assertNotIn('phone_number', item)
            self.assertNotIn('principal', item)
            # Response must only have id, name, institution_type, eiin, district_name
            allowed_keys = {'id', 'name', 'institution_type', 'eiin', 'district_name'}
            self.assertTrue(set(item.keys()).issubset(allowed_keys))

    def test_filtering_by_type_and_district(self):
        # Filter by type=college
        res = self.client.get('/api/institutions/search/?q=TEST&type=college')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['name'], 'SAMPLE TEST INSTITUTION 2')

        # Filter by district
        res = self.client.get('/api/institutions/search/?q=TEST&district=OTHER DISTRICT')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['name'], 'TEST INSTITUTION 3 BETA')

    @patch('api.views_search.InstitutionAnonThrottle.wait', return_value=60)
    @patch('api.views_search.InstitutionAnonThrottle.allow_request', return_value=False)
    def test_throttling_enforced(self, mock_allow, mock_wait):
        res = self.client.get('/api/institutions/search/?q=TEST')
        self.assertEqual(res.status_code, status.HTTP_429_TOO_MANY_REQUESTS)



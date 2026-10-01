import os
import tempfile
from unittest.mock import patch
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient
from api.models import Institution, District, Division, InstitutionAlias
from api.management.commands.institution_import_utils import load_institution_aliases_from_csv


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
        res = self.client.get('/api/institutions/search/?q=')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json(), [])

        res = self.client.get('/api/institutions/search/?q=T')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json(), [])

        res = self.client.get('/api/institutions/search/?q=   ')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.json(), [])

    def test_prefix_matches_first_then_contains(self):
        res = self.client.get('/api/institutions/search/?q=TEST')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 3)

        self.assertTrue(data[0]['name'].startswith('TEST'))
        self.assertTrue(data[1]['name'].startswith('TEST'))
        self.assertEqual(data[2]['name'], 'SAMPLE TEST INSTITUTION 2')

    def test_case_insensitive_matching(self):
        res = self.client.get('/api/institutions/search/?q=test')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.json()), 3)

    def test_all_words_matching_any_order(self):
        res = self.client.get('/api/institutions/search/?q=ALPHA%20TEST')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['name'], 'TEST INSTITUTION 1 ALPHA')

    def test_result_limit_ten(self):
        for i in range(4, 16):
            Institution.objects.create(
                name=f'TEST INSTITUTION {i}',
                eiin=f'9990{i:02d}',
                institution_type='school',
                district=self.district,
                district_name='TEST DISTRICT 1',
            )

        res = self.client.get('/api/institutions/search/?q=TEST')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 10)

    def test_search_by_alias(self):
        InstitutionAlias.objects.create(
            alias='TEST_ACRONYM',
            eiin='999001',
            institution=self.inst1,
            source_note='fake test note'
        )

        res = self.client.get('/api/institutions/search/?q=TEST_ACRONYM')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['name'], 'TEST INSTITUTION 1 ALPHA')
        self.assertEqual(data[0]['eiin'], '999001')

    def test_load_institution_aliases_loader(self):
        with tempfile.NamedTemporaryFile('w', delete=False, suffix='.csv', encoding='utf-8') as f:
            f.write("alias,eiin,source_note\n")
            f.write("FAKE_ALIAS_TEST,999002,fake test note\n")
            f.write("INVALID_ROW,\n")
            temp_path = f.name

        try:
            loaded, skipped = load_institution_aliases_from_csv(temp_path)
            self.assertEqual(loaded, 1)
            self.assertEqual(skipped, 1)

            alias_obj = InstitutionAlias.objects.get(alias='FAKE_ALIAS_TEST')
            self.assertEqual(alias_obj.eiin, '999002')
            self.assertEqual(alias_obj.institution, self.inst2)
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

    def test_no_email_or_personal_fields_in_response(self):
        res = self.client.get('/api/institutions/search/?q=TEST')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        for item in res.json():
            self.assertNotIn('email', item)
            self.assertNotIn('phone', item)
            self.assertNotIn('phone_number', item)
            self.assertNotIn('principal', item)
            allowed_keys = {'id', 'name', 'institution_type', 'eiin', 'district_name'}
            self.assertTrue(set(item.keys()).issubset(allowed_keys))

    def test_filtering_by_type_and_district(self):
        res = self.client.get('/api/institutions/search/?q=TEST&type=college')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['name'], 'SAMPLE TEST INSTITUTION 2')

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

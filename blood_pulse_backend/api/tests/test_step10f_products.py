# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import TestCase
from django.core.management import call_command
from django.core.management.base import CommandError
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from api.models import Product, ProductImage

User = get_user_model()


class Step10FProductsTestCase(TestCase):
    def setUp(self):
        from django.core.cache import cache
        cache.clear()
        self.client = APIClient()
        # Seed products using the management command
        call_command('seed_products', '--i-understand-this-creates-demo-data')

    def test_seed_products_safety_flag_required(self):
        with self.assertRaises(CommandError):
            call_command('seed_products')

    def test_products_list_public_and_count(self):
        res = self.client.get('/api/products/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn('results', data)
        self.assertEqual(data['count'], 8)
        self.assertEqual(len(data['results']), 8)

        # Ensure honesty: no fake ratings or review counts
        first_item = data['results'][0]
        self.assertNotIn('rating', first_item)
        self.assertNotIn('reviews_count', first_item)
        self.assertIn('price_range_text', first_item)
        self.assertIn('store_name', first_item)

    def test_filter_by_tier(self):
        res_t1 = self.client.get('/api/products/?tier=1')
        self.assertEqual(res_t1.status_code, 200)
        items = res_t1.json()['results']
        self.assertTrue(all(p['tier'] == 1 for p in items))
        self.assertEqual(len(items), 2)

        res_t4 = self.client.get('/api/products/?tier=4')
        self.assertEqual(res_t4.status_code, 200)
        items_t4 = res_t4.json()['results']
        self.assertTrue(all(p['tier'] == 4 for p in items_t4))
        self.assertEqual(len(items_t4), 2)

    def test_search_query(self):
        res = self.client.get('/api/products/?q=Omron')
        self.assertEqual(res.status_code, 200)
        results = res.json()['results']
        self.assertEqual(len(results), 1)
        self.assertIn('Omron', results[0]['name'])

    def test_product_detail(self):
        product = Product.objects.first()
        res = self.client.get(f'/api/products/{product.id}/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['id'], product.id)
        self.assertEqual(data['name'], product.name)
        self.assertGreater(len(data['images']), 0)

    def test_inactive_products_excluded_from_public_api(self):
        product = Product.objects.first()
        product.is_active = False
        product.save(update_fields=['is_active'])

        # Query without cache
        from django.core.cache import cache
        cache.clear()

        res = self.client.get('/api/products/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()['count'], 7)

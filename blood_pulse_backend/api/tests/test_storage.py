# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from django.test import SimpleTestCase
from api.services.storage import LocalStorage, CloudinaryStorage

class MediaStorageTests(SimpleTestCase):
    def test_local_storage_lifecycle(self):
        storage = LocalStorage()
        sample_bytes = b"fake-png-content"
        result = storage.upload_image(sample_bytes, "avatar.png", folder="profiles")

        self.assertIn("url", result)
        self.assertEqual(result["public_id"], "profiles/avatar.png")
        self.assertIn("profiles/avatar.png", storage.store)

        # Deletion
        deleted = storage.delete_image("profiles/avatar.png")
        self.assertTrue(deleted)
        self.assertNotIn("profiles/avatar.png", storage.store)

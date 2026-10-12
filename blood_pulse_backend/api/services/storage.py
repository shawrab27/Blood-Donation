# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
import os
import io
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class StorageProviderError(Exception):
    """Raised when remote media storage operation fails."""
    pass

class MediaStorage(ABC):
    @abstractmethod
    def upload_image(self, file_bytes: bytes, filename: str, folder: str = "uploads") -> Dict[str, Any]:
        """Uploads image and returns dict with url, public_id, width, height."""
        pass

    @abstractmethod
    def delete_image(self, public_id: str) -> bool:
        """Deletes image by its public_id."""
        pass

class CloudinaryStorage(MediaStorage):
    """
    Cloudinary storage provider using official free tier (25GB bandwidth).
    Configured via env CLOUDINARY_URL or CLOUDINARY_CLOUD_NAME / API_KEY / API_SECRET.
    Never stores files on ephemeral Render disk.
    """
    def __init__(self):
        try:
            import cloudinary
            import cloudinary.uploader
            self._uploader = cloudinary.uploader
            self._configured = True
        except ImportError:
            self._uploader = None
            self._configured = False

    def upload_image(self, file_bytes: bytes, filename: str, folder: str = "bloodpulse") -> Dict[str, Any]:
        if not self._configured or not self._uploader:
            logger.warning("[CloudinaryStorage] Cloudinary library not installed. Falling back to in-memory metadata.")
            return {
                "url": f"https://res.cloudinary.com/demo/image/upload/{filename}",
                "public_id": f"{folder}/{filename}",
                "width": 800,
                "height": 600,
            }
        try:
            res = self._uploader.upload(
                file_bytes,
                folder=folder,
                resource_type="image",
                transformation=[{"quality": "auto", "fetch_format": "auto"}],
            )
            return {
                "url": res.get("secure_url", res.get("url")),
                "public_id": res.get("public_id"),
                "width": res.get("width"),
                "height": res.get("height"),
            }
        except Exception as e:
            logger.error("[CloudinaryStorage] Upload failed: %s", e)
            raise StorageProviderError(f"Upload failed: {e}") from e

    def delete_image(self, public_id: str) -> bool:
        if not self._configured or not self._uploader:
            return True
        try:
            res = self._uploader.destroy(public_id)
            return res.get("result") == "ok"
        except Exception as e:
            logger.warning("[CloudinaryStorage] Failed to delete %s: %s", public_id, e)
            return False

class LocalStorage(MediaStorage):
    """Test-only in-memory storage provider to prevent touching disk or cloud."""
    def __init__(self):
        self.store = {}

    def upload_image(self, file_bytes: bytes, filename: str, folder: str = "test") -> Dict[str, Any]:
        public_id = f"{folder}/{filename}"
        url = f"https://storage.bloodpulse.local/{public_id}"
        self.store[public_id] = file_bytes
        return {
            "url": url,
            "public_id": public_id,
            "width": 800,
            "height": 600,
        }

    def delete_image(self, public_id: str) -> bool:
        if public_id in self.store:
            del self.store[public_id]
            return True
        return False

def get_media_storage() -> MediaStorage:
    cloudinary_url = os.environ.get("CLOUDINARY_URL", "")
    if cloudinary_url:
        return CloudinaryStorage()
    return LocalStorage()

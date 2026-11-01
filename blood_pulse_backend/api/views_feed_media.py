# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework.parsers import MultiPartParser, FormParser
from django.utils import timezone
from api.models import MediaUploadRecord, UserLocationState, District, Division
from api.services.storage import get_media_storage, StorageProviderError
from api.services.images import strip_image_exif
from api.data.district_centroids import find_nearest_district

logger = logging.getLogger(__name__)

class MediaUploadView(APIView):
    """
    POST /api/media/upload/
    Accepts multipart/form-data with 'file'.
    Strips EXIF/GPS, validates max 5MB, uploads via MediaStorage (Cloudinary / Local in-memory),
    and records MediaUploadRecord for orphan tracking.
    """
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, *args, **kwargs):
        file_obj = request.FILES.get('file') or request.FILES.get('image')
        if not file_obj:
            return Response({'error': 'No file uploaded. Key must be "file" or "image".'}, status=status.HTTP_400_BAD_REQUEST)

        # 5MB size limit
        if file_obj.size > 5 * 1024 * 1024:
            return Response({'error': 'File size exceeds maximum allowed limit of 5MB.'}, status=status.HTTP_400_BAD_REQUEST)

        # Validate file extension
        filename = getattr(file_obj, 'name', 'upload.jpg')
        import os
        ext = os.path.splitext(filename)[1].lower()
        allowed_extensions = {'.jpg', '.jpeg', '.png', '.webp'}
        if ext not in allowed_extensions:
            return Response({'error': f'Invalid file extension {ext}. Allowed: jpg, jpeg, png, webp.'}, status=status.HTTP_400_BAD_REQUEST)

        # Validate MIME type & file extension (support JPEG, PNG, WEBP, HEIC/HEIF and octet-stream)
        content_type = getattr(file_obj, 'content_type', '').lower()
        ext = os.path.splitext(filename)[1].lower()
        allowed_mimes = {'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'application/octet-stream', ''}
        if content_type and content_type not in allowed_mimes:
            return Response({'error': f'Invalid content type {content_type}. Allowed: image/jpeg, image/png, image/webp.'}, status=status.HTTP_400_BAD_REQUEST)

        # Verify image integrity via PIL
        try:
            from PIL import Image
            img = Image.open(file_obj)
            img.verify()
            file_obj.seek(0)
        except Exception:
            return Response({'error': 'Corrupted or invalid image file.'}, status=status.HTTP_400_BAD_REQUEST)

        # Strip EXIF / GPS metadata
        clean_file = strip_image_exif(file_obj)
        clean_bytes = clean_file.read() if hasattr(clean_file, 'read') else file_obj.read()

        # Compress and resize to max ~300KB (G-8)
        try:
            from PIL import Image
            import io
            img = Image.open(io.BytesIO(clean_bytes))
            if img.mode in ('RGBA', 'LA', 'P'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background

            # Downscale if exceeding 1280x1280
            max_dim = 1280
            if img.width > max_dim or img.height > max_dim:
                img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

            # Iteratively compress quality to max ~300KB
            quality = 85
            out_io = io.BytesIO()
            img.save(out_io, format='JPEG', quality=quality, optimize=True)
            while out_io.tell() > 300 * 1024 and quality > 30:
                quality -= 10
                out_io = io.BytesIO()
                img.save(out_io, format='JPEG', quality=quality, optimize=True)

            clean_bytes = out_io.getvalue()
        except Exception as compress_err:
            logger.warning("[MediaUploadView] Image compression failed, using original: %s", compress_err)

        storage = get_media_storage()
        try:
            upload_res = storage.upload_image(clean_bytes, filename=filename, folder='bloodpulse/feed')
        except StorageProviderError as e:
            logger.error("[MediaUploadView] Storage error: %s", e)
            return Response({'error': f'Failed to store media: {str(e)}'}, status=status.HTTP_502_BAD_GATEWAY)
        except Exception as e:
            logger.error("[MediaUploadView] Unexpected error: %s", e)
            return Response({'error': 'Internal media upload failure.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        record = MediaUploadRecord.objects.create(
            user=request.user,
            public_id=upload_res.get('public_id', ''),
            url=upload_res.get('url', ''),
            width=upload_res.get('width', 0) or 0,
            height=upload_res.get('height', 0) or 0,
        )

        return Response({
            'id': record.id,
            'url': record.url,
            'public_id': record.public_id,
            'width': record.width,
            'height': record.height,
        }, status=status.HTTP_201_CREATED)


class UserLocationSyncView(APIView):
    """
    POST /api/users/location/
    Receives coarse location {lat, lng} or {district_id} / {district_name}.
    Resolves nearest canonical district from 64 centroids, updates UserLocationState.
    Returns: {
        current_district_id,
        district_name,
        division_id,
        division_name,
        changed: bool
    }
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        lat = request.data.get('lat') or request.data.get('latitude')
        lng = request.data.get('lng') or request.data.get('longitude')
        district_id = request.data.get('district_id')
        district_name = request.data.get('district_name')
        source = request.data.get('source', 'gps')

        target_district = None

        if district_id:
            target_district = District.objects.filter(id=district_id).select_related('division').first()
        elif district_name:
            target_district = District.objects.filter(name__iexact=str(district_name).strip()).select_related('division').first()
        elif lat is not None and lng is not None:
            try:
                lat_f = float(lat)
                lng_f = float(lng)
                canonical_name = find_nearest_district(lat_f, lng_f)
                if canonical_name:
                    target_district = District.objects.filter(name__iexact=canonical_name).select_related('division').first()
            except (ValueError, TypeError):
                return Response({'error': 'Invalid latitude or longitude format.'}, status=status.HTTP_400_BAD_REQUEST)

        # Fallback to user profile district if not resolved
        if not target_district and request.user and request.user.is_authenticated:
            profile = getattr(request.user, 'donorprofile', None)
            if profile and profile.district:
                target_district = District.objects.filter(name__iexact=profile.district).select_related('division').first()
            source = 'profile'

        if request.user and request.user.is_authenticated:
            state_obj, _ = UserLocationState.objects.get_or_create(user=request.user)
            prev_district_id = state_obj.current_district_id
            changed = bool(target_district and target_district.id != prev_district_id)

            if target_district:
                state_obj.current_district = target_district
                state_obj.current_division = target_district.division
                state_obj.source = source
                state_obj.save()

            return Response({
                'current_district_id': state_obj.current_district_id,
                'district_name': state_obj.current_district.name if state_obj.current_district else None,
                'division_id': state_obj.current_division_id,
                'division_name': state_obj.current_division.name if state_obj.current_division else None,
                'source': state_obj.source,
                'changed': changed,
            }, status=status.HTTP_200_OK)

        return Response({
            'current_district_id': target_district.id if target_district else None,
            'district_name': target_district.name if target_district else None,
            'division_id': target_district.division_id if target_district else None,
            'division_name': target_district.division.name if (target_district and target_district.division) else None,
            'source': source,
            'changed': False,
        }, status=status.HTTP_200_OK)

    def get(self, request, *args, **kwargs):
        if not request.user or not request.user.is_authenticated:
            return Response({
                'current_district_id': None,
                'district_name': None,
                'division_id': None,
                'division_name': None,
                'source': 'profile',
                'changed': False,
            }, status=status.HTTP_200_OK)
        state_obj = UserLocationState.objects.filter(user=request.user).select_related('current_district', 'current_division').first()
        if not state_obj or not state_obj.current_district:
            profile = getattr(request.user, 'donorprofile', None)
            profile_dist = None
            if profile and profile.district:
                profile_dist = District.objects.filter(name__iexact=profile.district).select_related('division').first()
            return Response({
                'current_district_id': profile_dist.id if profile_dist else None,
                'district_name': profile_dist.name if profile_dist else (profile.district if profile else None),
                'division_id': profile_dist.division_id if profile_dist else None,
                'division_name': profile_dist.division.name if profile_dist and profile_dist.division else None,
                'source': 'profile',
                'changed': False,
            })

        return Response({
            'current_district_id': state_obj.current_district_id,
            'district_name': state_obj.current_district.name if state_obj.current_district else None,
            'division_id': state_obj.current_division_id,
            'division_name': state_obj.current_division.name if state_obj.current_division else None,
            'source': state_obj.source,
            'changed': False,
        })


import mimetypes
from django.http import HttpResponse, Http404

class MediaFileServeView(APIView):
    """Serves local uploaded media files cross-platform when remote CDN is unconfigured."""
    permission_classes = [permissions.AllowAny]

    def get(self, request, filename):
        import os
        from django.conf import settings

        # Path traversal guard: basename check + path must reside within MEDIA_ROOT
        safe_filename = os.path.basename(filename)
        if safe_filename != filename or not safe_filename or '..' in filename:
            raise Http404("Invalid filename")

        media_root = os.path.abspath(getattr(settings, 'MEDIA_ROOT', os.path.join(settings.BASE_DIR, 'media')))
        file_path = os.path.abspath(os.path.join(media_root, 'uploads', safe_filename))
        if not file_path.startswith(media_root) or not os.path.exists(file_path):
            file_path = os.path.abspath(os.path.join(media_root, safe_filename))
        if not file_path.startswith(media_root) or not os.path.exists(file_path):
            raise Http404("Media file not found")

        content_type, _ = mimetypes.guess_type(file_path)
        content_type = content_type or 'image/jpeg'
        with open(file_path, 'rb') as f:
            resp = HttpResponse(f.read(), content_type=content_type)
            resp['Access-Control-Allow-Origin'] = '*'
            resp['Cache-Control'] = 'public, max-age=86400'
            return resp

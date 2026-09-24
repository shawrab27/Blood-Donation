"""
Image Privacy & Metadata Sanitization Service.
Strips EXIF, GPS, device fingerprints, and camera metadata from user-uploaded images.
"""

import io
from PIL import Image
from django.core.files.base import ContentFile


def strip_image_exif(image_file) -> ContentFile:
    """
    Opens an image file, strips all EXIF/GPS metadata by recreating the raster image,
    and returns a clean ContentFile.
    """
    if not image_file:
        return None

    try:
        image = Image.open(image_file)
        
        # Clean image without copying info/exif dicts
        clean_img = Image.new(image.mode, image.size)
        clean_img.putdata(list(image.getdata()))

        output = io.BytesIO()
        img_format = image.format if image.format in ('JPEG', 'PNG', 'WEBP') else 'JPEG'
        
        if img_format == 'JPEG':
            clean_img = clean_img.convert('RGB')
            clean_img.save(output, format='JPEG', quality=85, optimize=True)
        else:
            clean_img.save(output, format=img_format, optimize=True)

        output.seek(0)
        file_name = getattr(image_file, 'name', 'cleaned_image.jpg')
        return ContentFile(output.read(), name=file_name)

    except Exception:
        # If Pillow fails to process (e.g. PDF requisition slip), rewind and return original
        if hasattr(image_file, 'seek'):
            image_file.seek(0)
        return image_file

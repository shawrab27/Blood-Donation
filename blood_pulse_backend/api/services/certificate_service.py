# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import io
import os
from datetime import date
from django.conf import settings
from django.core.signing import TimestampSigner, BadSignature, SignatureExpired
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape, A4
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import qrcode

# Colors
PRIMARY_RED = colors.HexColor("#C30121")
DARK_CHARCOAL = colors.HexColor("#2B2B2B")
MUTED_GRAY = colors.HexColor("#666666")
GOLD_ACCENT = colors.HexColor("#D4AF37")
LIGHT_SURFACE = colors.HexColor("#FDF3F3")
WATERMARK_RED = colors.Color(0.765, 0.004, 0.129, alpha=0.08)

# Register Noto Sans Bengali font
FONTS_DIR = settings.BASE_DIR / 'fonts'
REGULAR_FONT_PATH = FONTS_DIR / 'NotoSansBengali-Regular.ttf'
BOLD_FONT_PATH = FONTS_DIR / 'NotoSansBengali-Bold.ttf'

FONT_NAME = 'Helvetica'
BOLD_FONT_NAME = 'Helvetica-Bold'

if REGULAR_FONT_PATH.exists():
    try:
        pdfmetrics.registerFont(TTFont('NotoSansBengali', str(REGULAR_FONT_PATH)))
        FONT_NAME = 'NotoSansBengali'
    except Exception:
        pass

if BOLD_FONT_PATH.exists():
    try:
        pdfmetrics.registerFont(TTFont('NotoSansBengali-Bold', str(BOLD_FONT_PATH)))
        BOLD_FONT_NAME = 'NotoSansBengali-Bold'
    except Exception:
        pass


def generate_verification_token(donor_profile, verified_bags: int, issue_date: date) -> str:
    """Signs a tamper-proof verification token containing minimal certificate facts."""
    signer = TimestampSigner(salt='bloodpulse-certificate-v1')
    payload = f"{donor_profile.id}:{verified_bags}:{issue_date.isoformat()}"
    return signer.sign(payload)


def verify_certificate_token(token: str) -> dict:
    """
    Validates a certificate token and extracts donor verification facts.
    Returns minimal public data without any PII.
    """
    signer = TimestampSigner(salt='bloodpulse-certificate-v1')
    try:
        payload = signer.unsign(token)
        parts = payload.split(':')
        donor_id = int(parts[0])
        bags = int(parts[1])
        issue_date_str = parts[2]

        from api.models import DonorProfile
        donor = DonorProfile.objects.filter(id=donor_id).select_related('user').first()
        if not donor:
            return {"valid": False, "detail": "Donor record not found."}

        full_name = f"{donor.user.first_name} {donor.user.last_name}".strip() or donor.user.username
        return {
            "valid": True,
            "donor_id": f"BP-D{donor.id:06d}",
            "name": full_name,
            "blood_group": donor.blood_group,
            "verified_bags": bags,
            "issue_date": issue_date_str,
        }
    except (BadSignature, SignatureExpired, ValueError, IndexError):
        return {"valid": False, "detail": "Invalid or tampered certificate token."}


def generate_donor_certificate_pdf(donor_profile, verified_bags: int, issue_date: date = None) -> bytes:
    """
    Generates a PDF certificate with:
    - Diagonal 'BloodPulse' watermark
    - Donor name (with full Bengali script support via Noto Sans Bengali)
    - Blood group, verified bags donated, donor ID, issue date
    - Dynamic QR code pointing to public verification endpoint
    """
    if issue_date is None:
        issue_date = date.today()

    token = generate_verification_token(donor_profile, verified_bags, issue_date)
    base_url = (
        getattr(settings, 'CERTIFICATE_VERIFY_BASE_URL', '')
        or getattr(settings, 'SITE_URL', '')
        or getattr(settings, 'FRONTEND_URL', '')
        or 'https://api.bloodpulse.org'
    ).rstrip('/')
    verify_url = f"{base_url}/api/profile/certificate/verify/?token={token}"

    # Generate QR Code image in memory
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=4,
        border=1,
    )
    qr.add_data(verify_url)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="#C30121", back_color="white")
    qr_buffer = io.BytesIO()
    qr_img.save(qr_buffer, format='PNG')
    qr_buffer.seek(0)

    # Setup Landscape A4 Canvas
    pdf_buffer = io.BytesIO()
    page_width, page_height = landscape(A4)
    c = canvas.Canvas(pdf_buffer, pagesize=(page_width, page_height))
    c.setTitle(f"BloodPulse Verified Certificate - {donor_profile.id}")

    # 1. Background Frame & Borders
    c.setStrokeColor(PRIMARY_RED)
    c.setLineWidth(3)
    c.rect(20, 20, page_width - 40, page_height - 40)

    c.setStrokeColor(GOLD_ACCENT)
    c.setLineWidth(1)
    c.rect(26, 26, page_width - 52, page_height - 52)

    # 2. Diagonal Watermark across canvas
    c.saveState()
    c.setFont(BOLD_FONT_NAME, 80)
    c.setFillColor(WATERMARK_RED)
    c.translate(page_width / 2, page_height / 2)
    c.rotate(30)
    c.drawCentredString(0, -20, "BloodPulse")
    c.restoreState()

    # 3. Header
    c.setFillColor(PRIMARY_RED)
    c.setFont(BOLD_FONT_NAME, 32)
    c.drawCentredString(page_width / 2, page_height - 80, "BloodPulse")

    c.setFillColor(DARK_CHARCOAL)
    c.setFont(BOLD_FONT_NAME, 16)
    c.drawCentredString(page_width / 2, page_height - 110, "CERTIFICATE OF VERIFIED DONATION")

    c.setFillColor(MUTED_GRAY)
    c.setFont(FONT_NAME, 10)
    c.drawCentredString(page_width / 2, page_height - 128, "NATIONAL BLOOD DONOR RECOGNITION NETWORK • BANGLADESH")

    # Divider line
    c.setStrokeColor(PRIMARY_RED)
    c.setLineWidth(1.5)
    c.line(page_width / 2 - 120, page_height - 140, page_width / 2 + 120, page_height - 140)

    # 4. Certification Body
    c.setFillColor(DARK_CHARCOAL)
    c.setFont(FONT_NAME, 13)
    c.drawCentredString(page_width / 2, page_height - 180, "This is to officially recognize and honor")

    # Donor Name in Large Bold
    donor_name = f"{donor_profile.user.first_name} {donor_profile.user.last_name}".strip() or donor_profile.user.username
    c.setFillColor(PRIMARY_RED)
    c.setFont(BOLD_FONT_NAME, 26)
    c.drawCentredString(page_width / 2, page_height - 220, donor_name)

    # Underline under name
    c.setStrokeColor(colors.HexColor("#E0E0E0"))
    c.setLineWidth(1)
    name_width = min(350, max(200, len(donor_name) * 14))
    c.line(page_width / 2 - name_width / 2, page_height - 230, page_width / 2 + name_width / 2, page_height - 230)

    # Achievement narrative
    c.setFillColor(DARK_CHARCOAL)
    c.setFont(FONT_NAME, 12)
    c.drawCentredString(
        page_width / 2, page_height - 260,
        f"for outstanding commitment to humanity and saving lives as a registered verified donor."
    )

    c.setFont(BOLD_FONT_NAME, 14)
    c.drawCentredString(
        page_width / 2, page_height - 285,
        f"Blood Group: {donor_profile.blood_group}    •    Verified Donations Completed: {verified_bags} Bag(s)"
    )

    # Donor ID and Location
    c.setFillColor(MUTED_GRAY)
    c.setFont(FONT_NAME, 10)
    district_info = f" • Region: {donor_profile.district}" if donor_profile.district else ""
    c.drawCentredString(
        page_width / 2, page_height - 310,
        f"Donor ID: BP-D{donor_profile.id:06d}{district_info}"
    )

    # 5. Bottom Section: Signatures & QR Code
    # Issue date and signature
    c.setFillColor(DARK_CHARCOAL)
    c.setFont(FONT_NAME, 10)
    c.drawString(60, 95, f"Date of Issue: {issue_date.strftime('%d %B %Y')}")

    c.setStrokeColor(DARK_CHARCOAL)
    c.setLineWidth(1)
    c.line(60, 65, 220, 65)
    c.drawString(60, 50, "Verification Officer")
    c.setFont(FONT_NAME, 8)
    c.setFillColor(MUTED_GRAY)
    c.drawString(60, 38, "BloodPulse Trust & Safety Division")

    # Center Gold Badge / Seal
    c.setStrokeColor(GOLD_ACCENT)
    c.setFillColor(LIGHT_SURFACE)
    c.circle(page_width / 2, 70, 32, fill=1, stroke=1)
    c.setFillColor(PRIMARY_RED)
    c.setFont(BOLD_FONT_NAME, 9)
    c.drawCentredString(page_width / 2, 75, "VERIFIED")
    c.drawCentredString(page_width / 2, 63, "DONOR")

    # QR Code on Right
    from reportlab.lib.utils import ImageReader
    qr_reader = ImageReader(qr_buffer)
    qr_size = 76
    qr_x = page_width - 60 - qr_size
    qr_y = 48
    c.drawImage(qr_reader, qr_x, qr_y, width=qr_size, height=qr_size)

    c.setFillColor(MUTED_GRAY)
    c.setFont(FONT_NAME, 7)
    c.drawCentredString(qr_x + qr_size / 2, qr_y - 10, "Scan to Verify Authenticity")

    c.showPage()
    c.save()

    pdf_buffer.seek(0)
    return pdf_buffer.getvalue()

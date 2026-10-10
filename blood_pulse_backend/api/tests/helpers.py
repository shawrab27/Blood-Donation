# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Test helper for obtaining valid single-use submit_tokens through the real flow.
"""

from api.models import EmailOTP
from api.services.email import hash_otp


def obtain_submit_token_via_flow(client, user, email=None) -> str:
    """
    Obtains a submit_token through the real /api/requests/otp/send/ and verify/ endpoints.
    Used in test suites to satisfy mandatory submit_token enforcement.
    """
    target_email = (email or user.email or 'test@bloodpulse.org').strip().lower()
    client.force_authenticate(user=user)
    client.post('/api/requests/otp/send/', {'email': target_email}, format='json')

    otp_rec = (
        EmailOTP.objects
        .filter(user=user, purpose='blood_request_submit', is_used=False)
        .order_by('-created_at')
        .first()
    )
    if not otp_rec:
        otp_rec = (
            EmailOTP.objects
            .filter(email=target_email, purpose='blood_request_submit', is_used=False)
            .order_by('-created_at')
            .first()
        )

    test_code = '938102'
    otp_rec.otp_hash = hash_otp(test_code, otp_rec.email)
    otp_rec.save()

    res = client.post('/api/requests/otp/verify/', {'code': test_code, 'email': target_email}, format='json')
    return res.data['submit_token']

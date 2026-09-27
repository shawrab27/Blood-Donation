import random
from datetime import timedelta
from django.utils import timezone
from django.core.mail import send_mail
from django.contrib.auth.models import User
from django.contrib.auth.hashers import make_password, check_password
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.core.signing import TimestampSigner, BadSignature, SignatureExpired
from django.conf import settings
from .models import PasswordResetOTP

signer = TimestampSigner()

@api_view(['POST'])
@permission_classes([AllowAny])
def request_otp(request):
    email = request.data.get('email')
    if not email:
        return Response({'detail': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Generic success response function to prevent email enumeration
    def generic_success():
        return Response({'detail': 'If the email exists, an OTP has been sent.'}, status=status.HTTP_200_OK)
    
    user = User.objects.filter(email=email).first()
    if not user:
        return generic_success()
    
    # Rate limit: max 3 requests per email per 15 minutes
    fifteen_mins_ago = timezone.now() - timedelta(minutes=15)
    recent_requests = PasswordResetOTP.objects.filter(user=user, created_at__gte=fifteen_mins_ago).count()
    if recent_requests >= 3:
        return Response({'detail': 'Too many requests. Please try again later.'}, status=status.HTTP_429_TOO_MANY_REQUESTS)
    
    # Generate 6-digit OTP
    otp_code = str(random.randint(100000, 999999))
    
    # Store it
    PasswordResetOTP.objects.create(
        user=user,
        code_hash=make_password(otp_code),
        expires_at=timezone.now() + timedelta(minutes=10)
    )
    
    # Send email
    send_mail(
        subject="Your Blood Pulse Password Reset Code",
        message=f"Your Blood Pulse verification code is: {otp_code}. This code expires in 10 minutes. If you didn't request this, ignore this email.",
        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@bloodpulse.app'),
        recipient_list=[user.email],
        fail_silently=True,
    )
    
    return generic_success()

@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    email = request.data.get('email')
    code = request.data.get('code')
    
    if not email or not code:
        return Response({'detail': 'Email and code are required.'}, status=status.HTTP_400_BAD_REQUEST)
        
    user = User.objects.filter(email=email).first()
    if not user:
        return Response({'detail': 'Invalid or expired code.'}, status=status.HTTP_400_BAD_REQUEST)
        
    # Get the latest unused, unexpired OTP for this user
    otp_record = PasswordResetOTP.objects.filter(
        user=user,
        used=False,
    ).order_by('-created_at').first()
    
    if not otp_record:
        return Response({'detail': 'Invalid or expired code.'}, status=status.HTTP_400_BAD_REQUEST)
        
    # Rate limit verify attempts: max 5
    if otp_record.attempts >= 5:
        return Response({'detail': 'Too many failed attempts. Please request a new code.'}, status=status.HTTP_429_TOO_MANY_REQUESTS)
        
    otp_record.attempts += 1
    otp_record.save()
    
    # Check expiry
    if timezone.now() > otp_record.expires_at:
        return Response({'detail': 'Invalid or expired code.'}, status=status.HTTP_400_BAD_REQUEST)
        
    # Check hash
    if not check_password(str(code), otp_record.code_hash):
        return Response({'detail': 'Invalid or expired code.'}, status=status.HTTP_400_BAD_REQUEST)
        
    # Success
    otp_record.used = True
    # Generate signed token valid for 10 minutes using core.signing
    reset_token = signer.sign(f"{user.id}:{otp_record.id}")
    otp_record.reset_token = reset_token
    otp_record.save()
    
    return Response({'reset_token': reset_token}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    token = request.data.get('reset_token')
    new_password = request.data.get('new_password')
    confirm_password = request.data.get('confirm_password')
    
    if not token or not new_password or not confirm_password:
        return Response({'detail': 'All fields are required.'}, status=status.HTTP_400_BAD_REQUEST)
        
    if new_password != confirm_password:
        return Response({'detail': 'Passwords do not match.'}, status=status.HTTP_400_BAD_REQUEST)
        
    if len(new_password) < 8:
        return Response({'detail': 'Password must be at least 8 characters.'}, status=status.HTTP_400_BAD_REQUEST)
        
    try:
        # Token is valid for 10 minutes (600 seconds)
        unsigned_value = signer.unsign(token, max_age=600)
        user_id_str, otp_id_str = unsigned_value.split(':')
    except (BadSignature, SignatureExpired, ValueError):
        return Response({'detail': 'Invalid or expired reset token.'}, status=status.HTTP_400_BAD_REQUEST)
        
    otp_record = PasswordResetOTP.objects.filter(id=otp_id_str, user_id=user_id_str, reset_token=token).first()
    if not otp_record:
        return Response({'detail': 'Invalid reset token.'}, status=status.HTTP_400_BAD_REQUEST)
        
    user = otp_record.user
    user.set_password(new_password)
    user.save()
    
    # Invalidate token
    otp_record.reset_token = None
    otp_record.save()
    
    return Response({'detail': 'Password reset successful.'}, status=status.HTTP_200_OK)

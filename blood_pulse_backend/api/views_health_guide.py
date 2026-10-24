# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework import status
from django.utils import timezone
from datetime import timedelta, date
from django.conf import settings
from api.models import (
    DonorProfile, DonationHistory, DailyHydrationLog,
    GuideApplication, AreaGuide, Division, District, Upazila
)
from api.services.notifications import notify


class RecoveryStatusView(APIView):
    """
    GET /api/v1/health-hub/recovery-status/
    Computes post-donation recovery status from real last-donation timestamp on backend.
    """
    permission_classes = [AllowAny]

    def get(self, request, *args, **kwargs):
        # USER RULE - do not change: Strict C2 dynamic recovery tracker from real last-donation
        user = request.user
        if not user or not user.is_authenticated:
            return Response({
                'has_donated': False,
                'last_donation_date': None,
                'recovery_percentage': None,
                'elapsed_days': None,
                'elapsed_hours': None,
                'stage': None,
                'status_title': 'No Active Recovery Cycle',
                'status_message': 'Your recovery tracker starts after your first donation.',
                'hydration_glasses': 0,
                'is_eligible': True,
            })

        # Fetch donor profile
        profile = DonorProfile.objects.filter(user=user).first()
        latest_donation_date = None
        if profile and profile.last_donation_date:
            latest_donation_date = profile.last_donation_date
        else:
            # Check donation history
            latest_dh = DonationHistory.objects.filter(donor=profile).order_by('-donated_at').first() if profile else None
            if latest_dh and latest_dh.donated_at:
                latest_donation_date = latest_dh.donated_at

        # Fetch today's hydration
        today = timezone.now().date()
        hyd_log = DailyHydrationLog.objects.filter(user=user, date=today).first()
        today_glasses = hyd_log.glasses if hyd_log else 0

        if not latest_donation_date:
            return Response({
                'has_donated': False,
                'last_donation_date': None,
                'recovery_percentage': None,
                'elapsed_days': None,
                'elapsed_hours': None,
                'stage': None,
                'status_title': 'No Active Recovery Cycle',
                'status_message': 'Your recovery tracker starts after your first donation.',
                'hydration_glasses': today_glasses,
                'is_eligible': True,
            })

        elapsed_days = (today - latest_donation_date).days
        if elapsed_days < 0:
            elapsed_days = 0
        elapsed_hours = elapsed_days * 24

        # Recovery stages and percentages
        if elapsed_days <= 1:
            recovery_percentage = 25
            stage = "Plasma Volume Replenishment"
            status_title = "Plasma Volume Replenishment (24 Hours)"
            status_message = "It has been 24 hours since your donation. Plasma volume is 95% restored. Drink water and rest."
            is_eligible = False
        elif elapsed_days < 7:
            recovery_percentage = 40
            stage = "Platelet & White Blood Cell Regeneration"
            status_title = "Platelet & WBC Synthesis"
            status_message = f"It has been {elapsed_days} days since your donation. Platelets and white blood cells are actively regenerating."
            is_eligible = False
        elif elapsed_days < 28:
            recovery_percentage = 65
            stage = "Erythropoiesis & Red Blood Cell Synthesis"
            status_title = "Red Blood Cell Synthesis (7-28 Days)"
            status_message = f"It has been {elapsed_days} days since your donation. Bone marrow is actively replacing red blood cells."
            is_eligible = False
        elif elapsed_days < 56:
            recovery_percentage = 85
            stage = "Ferritin & Red Cell Maturation"
            status_title = "Iron Reserves Maturation (28-56 Days)"
            status_message = f"It has been {elapsed_days} days since your donation. Hemoglobin and ferritin stores are nearing full baseline."
            is_eligible = False
        else:
            recovery_percentage = 100
            stage = "Full Recovery Completed"
            status_title = "Full Biological Recovery (56 Days)"
            status_message = "Your red blood cells, iron reserves, and plasma are 100% restored. You are fully ready for your next voluntary donation!"
            is_eligible = True

        return Response({
            'has_donated': True,
            'last_donation_date': str(latest_donation_date),
            'recovery_percentage': recovery_percentage,
            'elapsed_days': elapsed_days,
            'elapsed_hours': elapsed_hours,
            'stage': stage,
            'status_title': status_title,
            'status_message': status_message,
            'hydration_glasses': today_glasses,
            'is_eligible': is_eligible,
        })


class HydrationView(APIView):
    """
    GET / POST /api/v1/health-hub/hydration/
    Stores and retrieves hydration glasses per day on the backend.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        today = timezone.now().date()
        log, _ = DailyHydrationLog.objects.get_or_create(user=request.user, date=today)
        return Response({
            'date': str(today),
            'glasses': log.glasses,
            'target_glasses': 10,
        })

    def post(self, request, *args, **kwargs):
        today = timezone.now().date()
        log, _ = DailyHydrationLog.objects.get_or_create(user=request.user, date=today)
        action = request.data.get('action')
        new_glasses = request.data.get('glasses')

        if action == 'add':
            log.glasses += 1
        elif action == 'remove':
            if log.glasses > 0:
                log.glasses -= 1
        elif new_glasses is not None:
            try:
                log.glasses = max(0, int(new_glasses))
            except (ValueError, TypeError):
                pass
        log.save(update_fields=['glasses', 'updated_at'])

        return Response({
            'date': str(today),
            'glasses': log.glasses,
            'target_glasses': 10,
        })


class GuideApplicationView(APIView):
    """
    GET / POST /api/v1/communities/guide-application/
    Handles Become a Guide application status and submission with strict rules (Phase F).
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        profile = getattr(user, 'donorprofile', None)

        # Account completion check
        is_complete = bool(profile and profile.is_profile_complete and profile.phone_number)
        if not is_complete:
            return Response({
                'status': 'gated',
                'can_apply': False,
                'message': 'Complete your profile to apply as a Local Area Guide.',
            })

        latest_app = GuideApplication.objects.filter(user=user).order_by('-created_at').first()
        if not latest_app:
            return Response({
                'status': 'none',
                'button_state': 'Apply Now',
                'can_apply': True,
            })

        if latest_app.status == GuideApplication.STATUS_PENDING:
            return Response({
                'status': 'pending',
                'button_state': 'Pending review',
                'can_apply': False,
                'applied_at': latest_app.created_at.isoformat(),
            })

        if latest_app.status == GuideApplication.STATUS_APPROVED:
            return Response({
                'status': 'approved',
                'button_state': 'Approved (Manage)',
                'can_apply': False,
                'is_guide': True,
                'approved_at': latest_app.reviewed_at.isoformat() if latest_app.reviewed_at else None,
            })

        if latest_app.status == GuideApplication.STATUS_REJECTED:
            # 14-day re-apply block
            cooldown_days = 14
            reviewed_date = latest_app.reviewed_at.date() if latest_app.reviewed_at else latest_app.created_at.date()
            reapply_date = reviewed_date + timedelta(days=cooldown_days)
            today = timezone.now().date()
            can_reapply = today >= reapply_date

            return Response({
                'status': 'rejected',
                'button_state': f'Rejected (Apply again on {reapply_date})' if not can_reapply else 'Apply Now',
                'can_apply': can_reapply,
                'reapply_date': str(reapply_date),
                'rejection_reason': latest_app.rejection_reason or 'Requirements not met.',
            })

        return Response({'status': 'none', 'button_state': 'Apply Now', 'can_apply': True})

    def post(self, request, *args, **kwargs):
        user = request.user
        profile = getattr(user, 'donorprofile', None)

        # 1. Gate: Only complete accounts may apply
        if not profile or not profile.is_profile_complete or not profile.phone_number:
            return Response(
                {'error': 'Only verified and complete donor profiles can apply to become a guide.'},
                status=status.HTTP_403_FORBIDDEN
            )

        # 2. Rule: none while one is pending
        pending = GuideApplication.objects.filter(user=user, status=GuideApplication.STATUS_PENDING).first()
        if pending:
            return Response(
                {'error': 'You already have a guide application pending review.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 3. Rule: rejection blocks re-apply for 14 days
        latest_rejected = GuideApplication.objects.filter(user=user, status=GuideApplication.STATUS_REJECTED).order_by('-reviewed_at').first()
        if latest_rejected and latest_rejected.reviewed_at:
            reapply_date = latest_rejected.reviewed_at.date() + timedelta(days=14)
            if timezone.now().date() < reapply_date:
                return Response(
                    {'error': f'Re-applications are locked for 14 days following rejection. You can re-apply on {reapply_date}.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # 4. Form validation
        intro = request.data.get('intro', '').strip()
        if not intro or len(intro) > 200:
            return Response(
                {'error': 'Introduction must be between 1 and 200 characters.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        allow_calls = bool(request.data.get('allow_calls', False))
        proof_photo = request.data.get('proof_photo', '').strip() or None
        area_name = request.data.get('area_name', '').strip()

        # Division / District / Upazila
        division_id = request.data.get('division')
        district_id = request.data.get('district')
        upazila_id = request.data.get('upazila')

        division_obj = Division.objects.filter(id=division_id).first() if division_id else None
        district_obj = District.objects.filter(id=district_id).first() if district_id else None
        upazila_obj = Upazila.objects.filter(id=upazila_id).first() if upazila_id else None

        app = GuideApplication.objects.create(
            user=user,
            division=division_obj,
            district=district_obj,
            upazila=upazila_obj,
            area_name=area_name,
            intro=intro,
            allow_calls=allow_calls,
            proof_photo=proof_photo,
            status=GuideApplication.STATUS_PENDING,
        )

        return Response({
            'status': 'pending',
            'button_state': 'Pending review',
            'message': 'Your Guide application has been submitted for staff review.',
            'id': app.id,
        }, status=status.HTTP_201_CREATED)

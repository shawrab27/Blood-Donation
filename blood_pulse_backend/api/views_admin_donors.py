from rest_framework import views, status, generics
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from api.models import DonorProfile, DonationHistory, AdminAction
from django.contrib.auth.models import User
from django.db.models import Count

class AdminDonorListAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        donors = DonorProfile.objects.select_related('user').annotate(
            total_donations=Count('donation_history')
        ).all()

        data = []
        for d in donors:
            score = min(100, 50 + d.total_donations * 10)
            band = 'HIGH' if score >= 80 else ('MEDIUM' if score >= 50 else 'LOW')
            data.append({
                'id': d.id,  # DonorProfile ID
                'user_id': d.user.id,
                'full_name': f"{d.user.first_name} {d.user.last_name}".strip() if d.user.first_name else d.user.username,
                'email': d.user.email,
                'phone': d.phone_number,
                'blood_group': d.blood_group,
                'trust_score': score,
                'trust_band': band,
                'total_donations': d.total_donations,
                'is_available': d.is_available,
                'is_active': d.user.is_active,
                'is_suspended': d.is_suspended,
            })
        
        return Response(data)

class AdminDonorExportAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def get(self, request, pk):
        try:
            donor = DonorProfile.objects.select_related('user').get(pk=pk)
        except DonorProfile.DoesNotExist:
            return Response({'error': 'Not found'}, status=404)
        
        history = DonationHistory.objects.filter(donor=donor).order_by('-date')
        history_data = [{'date': h.date, 'location': h.location} for h in history]
        
        score = min(100, 50 + history.count() * 10)

        data = {
            'profile': {
                'id': donor.id,
                'user_id': donor.user.id,
                'full_name': f"{donor.user.first_name} {donor.user.last_name}".strip(),
                'email': donor.user.email,
                'phone': donor.phone_number,
                'blood_group': donor.blood_group,
                'trust_score': score,
                'is_available': donor.is_available,
                'is_suspended': donor.is_suspended,
            },
            'history': history_data
        }

        AdminAction.objects.create(
            admin_user=request.user,
            action_type='EXPORT_DONOR_DATA',
            target_id=donor.id,
            notes=f'Exported full profile and history for donor {donor.id}'
        )

        return Response(data)

class AdminDonorVerifyAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            donor = DonorProfile.objects.get(pk=pk)
        except DonorProfile.DoesNotExist:
            return Response({'error': 'Not found'}, status=404)
            
        AdminAction.objects.create(
            admin_user=request.user,
            action_type='VERIFY_DONOR',
            target_id=donor.id,
            notes=f'Verified donor {donor.id}'
        )
        return Response({'status': 'verified'})

class AdminDonorSuspendAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            donor = DonorProfile.objects.get(pk=pk)
        except DonorProfile.DoesNotExist:
            return Response({'error': 'Not found'}, status=404)
        
        # Toggle suspension state
        donor.is_suspended = not donor.is_suspended
        
        if donor.is_suspended:
            donor.is_available = False
            action_str = 'SUSPEND_DONOR'
            status_str = 'suspended'
        else:
            donor.is_available = True
            action_str = 'UNSUSPEND_DONOR'
            status_str = 'unsuspended'
            
        donor.save(update_fields=['is_suspended', 'is_available'])
        
        AdminAction.objects.create(
            admin_user=request.user,
            action_type=action_str,
            target_id=donor.id,
            notes=f'Toggled donor {donor.id} suspension to {donor.is_suspended}'
        )
        
        return Response({'status': status_str, 'is_suspended': donor.is_suspended})

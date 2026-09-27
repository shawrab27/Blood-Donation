from rest_framework import views, status
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from django.contrib.auth.models import User
from api.models import AdminAction

class AdminStaffListAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        # Fetch only staff users
        staff = User.objects.filter(is_staff=True).order_by('-date_joined')
        data = []
        for s in staff:
            data.append({
                'id': s.id,
                'username': s.username,
                'name': f"{s.first_name} {s.last_name}".strip() or s.username,
                'email': s.email,
                'date_joined': s.date_joined,
                'last_login': s.last_login,
                'is_active': s.is_active
            })
        return Response(data)

class AdminStaffToggleAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        try:
            staff_user = User.objects.get(pk=pk, is_staff=True)
        except User.DoesNotExist:
            return Response({"error": "Staff account not found"}, status=status.HTTP_404_NOT_FOUND)
        
        # Prevent admins from accidentally locking themselves out
        if staff_user.id == request.user.id:
            return Response({"error": "Cannot toggle your own account status."}, status=status.HTTP_400_BAD_REQUEST)

        staff_user.is_active = not staff_user.is_active
        staff_user.save()

        # Audit Log
        action_text = "activated" if staff_user.is_active else "deactivated"
        AdminAction.objects.create(
            admin_user=request.user,
            action_type='TOGGLE_STAFF_ACTIVE',
            target_id=staff_user.id,
            notes=f"Admin {action_text} staff account '{staff_user.username}'."
        )

        return Response({
            "status": "success",
            "is_active": staff_user.is_active
        })

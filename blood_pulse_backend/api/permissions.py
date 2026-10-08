from rest_framework import permissions
from rest_framework.permissions import BasePermission
from rest_framework.exceptions import PermissionDenied

class IsProfileComplete(BasePermission):
    """
    Custom permission class granting access only if the user's profile is complete.
    Returns HTTP 403 with code 'profile_incomplete' and missing_fields on denial.
    """
    message = "Complete your registration to use this feature."

    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return True

        profile = getattr(request.user, 'donorprofile', None)
        if not profile:
            from api.models import DonorProfile
            profile = DonorProfile.objects.filter(user=request.user).first()

        if not profile:
            raise PermissionDenied(detail={
                "code": "profile_incomplete",
                "detail": "Complete your registration to use this feature.",
                "missing_fields": ["blood_group", "phone_number", "district", "full_name"]
            })

        is_comp, missing = profile.check_is_complete()
        if not is_comp:
            raise PermissionDenied(detail={
                "code": "profile_incomplete",
                "detail": "Complete your registration to use this feature.",
                "missing_fields": missing
            })
        return True


class IsRegistrationComplete(IsProfileComplete):
    """Compatibility alias for IsProfileComplete."""
    pass


class IsSuperAdminOrGroup(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser and request.user.is_staff:
            return True
        if request.user.groups.filter(name='administrators').exists():
            return True
        return False

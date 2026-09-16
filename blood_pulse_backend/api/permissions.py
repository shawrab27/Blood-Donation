from rest_framework.permissions import BasePermission

class IsProfileComplete(BasePermission):
    """
    Custom permission class granting access only if the user is authenticated
    and their associated DonorProfile has is_profile_complete set to True.
    """
    message = "Your donor profile must be complete to perform this action."

    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        
        try:
            return bool(hasattr(request.user, "donorprofile") and request.user.donorprofile.is_profile_complete)
        except Exception:
            return False


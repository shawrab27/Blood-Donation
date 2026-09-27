# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

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

from rest_framework import permissions

class IsSuperAdminOrGroup(permissions.BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser and request.user.is_staff:
            return True
        if request.user.groups.filter(name='administrators').exists():
            return True
        return False

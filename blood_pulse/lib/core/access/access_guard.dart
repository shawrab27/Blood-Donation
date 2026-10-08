// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import 'registration_gate_popup.dart';
import 'profile_completion_modal.dart';

/// Features gated by BloodPulse soft-wall access rules.
enum AccessFeature {
  feed,
  healthHub,
  bloodHub,
  chat,
  community,
  profile,
}

/// Local guest flag provider (never depends on an auth token).
final isGuestProvider = StateProvider<bool>((ref) => false);

/// Single source of truth for soft-wall access rules across BloodPulse.
class AccessGuard {
  const AccessGuard._();

  /// Pure decision function: determines if an action/screen is accessible.
  static bool canAccess({
    required AccessFeature feature,
    required bool isGuest,
    required bool isAuthenticated,
    required bool isProfileComplete,
  }) {
    // 1. Guest: Feed and Health Hub are open.
    //    Blood Hub, Chat, Profile, and Community are locked.
    if (isGuest) {
      switch (feature) {
        case AccessFeature.feed:
        case AccessFeature.healthHub:
          return true;
        case AccessFeature.bloodHub:
        case AccessFeature.chat:
        case AccessFeature.community:
        case AccessFeature.profile:
          return false;
      }
    }

    // 2. Logged-in user with is_profile_complete = false:
    //    Feed and Health Hub are open.
    //    Blood Hub, Chat, Community, and Profile are locked.
    //    (Profile screen may open only to show the profile completion form).
    if (isAuthenticated && !isProfileComplete) {
      switch (feature) {
        case AccessFeature.feed:
        case AccessFeature.healthHub:
          return true;
        case AccessFeature.bloodHub:
        case AccessFeature.chat:
        case AccessFeature.community:
        case AccessFeature.profile:
          return false;
      }
    }

    // 3. Complete user: no locks.
    if (isAuthenticated && isProfileComplete) {
      return true;
    }

    // Default for unauthenticated users (who haven't entered guest mode)
    return false;
  }

  /// Evaluates current Riverpod state and decides access.
  static bool canAccessCurrent(WidgetRef ref, AccessFeature feature) {
    final guest = ref.read(isGuestProvider);
    final authState = ref.read(authProvider);
    final isAuthenticated = authState.isAuthenticated || authState.user != null;
    final isComplete = authState.user?.isProfileComplete == true;

    return canAccess(
      feature: feature,
      isGuest: guest,
      isAuthenticated: isAuthenticated,
      isProfileComplete: isComplete,
    );
  }

  /// Intercepts navigation or tap actions:
  /// - If allowed: executes [onAllowed].
  /// - If locked for guest: opens "Complete your registration" popup.
  /// - If locked for incomplete user:
  ///   * on Profile: opens Profile completion form.
  ///   * on others: opens "Complete your registration" popup.
  static bool checkAndHandle({
    required BuildContext context,
    required WidgetRef ref,
    required AccessFeature feature,
    required VoidCallback onAllowed,
  }) {
    final guest = ref.read(isGuestProvider);
    final authState = ref.read(authProvider);
    final isAuthenticated = authState.isAuthenticated || authState.user != null;
    final isComplete = authState.user?.isProfileComplete == true;

    final allowed = canAccess(
      feature: feature,
      isGuest: guest,
      isAuthenticated: isAuthenticated,
      isProfileComplete: isComplete,
    );

    if (allowed) {
      onAllowed();
      return true;
    }

    if (guest) {
      RegistrationGatePopup.show(context, isGuest: true);
      return false;
    }

    if (isAuthenticated && !isComplete) {
      if (feature == AccessFeature.profile) {
        ProfileCompletionModal.show(context);
      } else {
        RegistrationGatePopup.show(context, isGuest: false);
      }
      return false;
    }

    // Unauthenticated fallback
    context.go('/login');
    return false;
  }
}

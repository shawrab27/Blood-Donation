import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';

import '../core/access/access_guard.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (next.status == AuthStatus.authenticated ||
            next.status == AuthStatus.authenticatedIncomplete) {
          if (ref.read(isGuestProvider)) {
            ref.read(isGuestProvider.notifier).state = false;
          }
        }
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
    ref.listen<bool>(
      isGuestProvider,
      (previous, next) {
        if (previous != next) {
          notifyListeners();
        }
      },
    );
  }

  final Ref ref;

  String? redirectLogic(BuildContext context, dynamic state) {
    final authState = ref.read(authProvider);
    final isGuest = ref.read(isGuestProvider);
    final path = state.uri.path;
    final isPreAuthRoute = path == '/login' || 
                           path == '/register' || 
                           path == '/forgot-password' ||
                           path == '/verify-otp' ||
                           path == '/language' ||
                           path == '/' || 
                           path == '/onboarding' || 
                           path == '/splash' ||
                           path == '/privacy-policy' ||
                           path == '/guest-welcome';
                        
    if (authState.status == AuthStatus.loading) {
      return null;
    }

    if (authState.status == AuthStatus.unauthenticated) {
      if (isGuest) {
        // Guest allowlist is exactly Welcome, Feed (read-only), Health Hub, National Emergency / Drill, and pre-auth flows
        final isGuestAllowed = path == '/guest-welcome' ||
                               path == '/feed' ||
                               path == '/health-hub' ||
                               path.startsWith('/health-hub/') ||
                               path == '/assistant' ||
                               path == '/emergency/national' ||
                               isPreAuthRoute;

        if (!isGuestAllowed) {
          // Deep link or locked navigation: redirect to guest welcome without looping
          return '/guest-welcome';
        }
        return null;
      }

      if (!isPreAuthRoute) {
        return '/login';
      }
      return null;
    }

    if (authState.status == AuthStatus.authenticated || authState.status == AuthStatus.authenticatedIncomplete) {
      final isAuthFlow = path == '/login' || 
                         path == '/forgot-password' ||
                         path == '/verify-otp' ||
                         path == '/onboarding' || 
                         path == '/splash' ||
                         path == '/guest-welcome';
      if (isAuthFlow) {
        return '/feed'; // Feed is the default; logged-in users never stay on /guest-welcome
      }
    }
    
    // Explicitly block deep links to locked features when incomplete (except national emergency/drill)
    if (authState.status == AuthStatus.authenticatedIncomplete) {
      if (path == '/emergency/national') {
        return null;
      }
      if (path == '/profile' || 
          path.startsWith('/profile/') ||
          path == '/edit-profile' || 
          path.startsWith('/edit-profile/') ||
          path == '/blood-hub' || 
          path.startsWith('/blood-hub/') ||
          path == '/emergency' ||
          (path.startsWith('/emergency/') && path != '/emergency/national') ||
          path == '/emergency-request' ||
          path == '/create-request' ||
          path == '/live-dispatch' ||
          path == '/journeys' ||
          path.startsWith('/journeys/') ||
          path == '/map' ||
          path.startsWith('/standby/')) {
        return '/feed';
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
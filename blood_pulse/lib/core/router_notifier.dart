import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
  }

  final Ref ref;

  String? redirectLogic(BuildContext context, dynamic state) {
    final authState = ref.read(authProvider);
    final path = state.uri.path;
    final isPreAuthRoute = path == '/login' || 
                           path == '/register' || 
                           path == '/otp-verify' ||
                           path == '/forgot-password' ||
                           path == '/verify-otp' ||
                           path == '/language' ||
                           path == '/' || 
                           path == '/onboarding' || 
                           path == '/splash' ||
                           path == '/privacy-policy';
                        
    if (authState.status == AuthStatus.unauthenticated) {
      if (!isPreAuthRoute) {
        return '/login';
      }
      return null;
    }

    if (authState.status == AuthStatus.authenticated || authState.status == AuthStatus.authenticatedIncomplete) {
      final isAuthFlow = path == '/login' || 
                         path == '/register' || 
                         path == '/otp-verify' ||
                         path == '/forgot-password' ||
                         path == '/verify-otp' ||
                         path == '/' || 
                         path == '/onboarding' || 
                         path == '/splash';
      if (isAuthFlow) {
        return '/feed'; // Feed is the default
      }
    }
    
    // Explicitly block deep links to locked features when incomplete
    if (authState.status == AuthStatus.authenticatedIncomplete) {
      if (path == '/profile' || 
          path.startsWith('/profile/') ||
          path == '/edit-profile' || 
          path.startsWith('/edit-profile/') ||
          path == '/blood-hub' || 
          path.startsWith('/blood-hub/') ||
          path == '/emergency' ||
          path.startsWith('/emergency/') ||
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
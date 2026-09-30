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
    final isLoggingIn = state.uri.path == '/login' || 
                        state.uri.path == '/register' || 
                        state.uri.path == '/' || 
                        state.uri.path == '/onboarding' || 
                        state.uri.path == '/splash';
                        
    if (authState.status == AuthStatus.unauthenticated) {
      if (!isLoggingIn) {
        return '/login';
      }
      return null;
    }

    if (authState.status == AuthStatus.authenticated || authState.status == AuthStatus.authenticatedIncomplete) {
      if (isLoggingIn) {
        return '/feed'; // Feed is the default
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

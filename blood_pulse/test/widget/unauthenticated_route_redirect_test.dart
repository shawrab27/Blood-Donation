import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/main.dart';
import 'package:blood_pulse/core/app_router.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/notifications/domain/providers/notification_provider.dart';

class FakeNotificationCountNotifier extends NotificationCountNotifier {
  FakeNotificationCountNotifier();
}

class FakeUnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      user: null,
    );
  }
}

void main() {
  testWidgets('Unauthenticated user can reach pre-auth routes and is redirected to /login from authenticated routes', (WidgetTester tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => FakeUnauthenticatedAuthNotifier()),
        notificationCountProvider.overrideWith((ref) => FakeNotificationCountNotifier()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BloodPulseApp(),
      ),
    );

    // Initial pump
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final router = container.read(appRouterProvider);

    // 1. Can reach /language
    router.go('/language');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/language');

    // 2. Can reach /forgot-password
    router.go('/forgot-password');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/forgot-password');

    // 3. Can reach /verify-otp
    router.go('/verify-otp', extra: 'user@example.com');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/verify-otp');

    // 4. Redirected to /login from /feed
    router.go('/feed');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');

    // 5. Redirected to /login from /blood-hub
    router.go('/blood-hub');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

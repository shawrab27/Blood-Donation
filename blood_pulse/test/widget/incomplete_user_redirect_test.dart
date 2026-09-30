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

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticatedIncomplete,
      user: UserProfile(
        fullName: 'Incomplete User',
        email: 'inc@test.com',
        primaryPhone: '017',
        bloodGroup: 'A+',
        category: 'civilian',
        categoryDetails: {},
        isProfileComplete: false,
        isOtpVerified: true,
        totalBagsDonated: 0,
        age: 25,
        gender: 'Male',
        neverDonated: true,
      ),
    );
  }
}

void main() {
  testWidgets('authenticatedIncomplete user pushing /profile and /blood-hub is redirected to /feed', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => FakeAuthNotifier()),
        notificationCountProvider.overrideWith((ref) => FakeNotificationCountNotifier()),
      ],
    );

    // We pump BloodPulseApp which uses appRouterProvider
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BloodPulseApp(),
      ),
    );

    // pump for HeartbeatIcon
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final router = container.read(appRouterProvider);

    // Default route for authenticatedIncomplete is /feed
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    // Try pushing /profile
    router.go('/profile');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    // Try pushing /blood-hub
    router.go('/blood-hub');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');
    
    // Test subroutes
    router.go('/profile/edit');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    router.go('/edit-profile');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    router.go('/blood-hub/search');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    router.go('/blood-hub/request/direct');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    // Test extended emergency and live-dispatch routes
    router.go('/emergency');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    router.go('/live-dispatch');
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/core/access/access_guard.dart';

void main() {
  group('AccessGuard pure logic tests', () {
    test('Guest: Feed and Health Hub are open; Blood Hub, Chat, Community, Profile are locked', () {
      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.feed,
          isGuest: true,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isTrue,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.healthHub,
          isGuest: true,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isTrue,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.bloodHub,
          isGuest: true,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isFalse,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.chat,
          isGuest: true,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isFalse,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.community,
          isGuest: true,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isFalse,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.profile,
          isGuest: true,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isFalse,
      );
    });

    test('Incomplete logged-in user: Feed & Health Hub open; Blood Hub, Chat, Community, Profile locked', () {
      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.feed,
          isGuest: false,
          isAuthenticated: true,
          isProfileComplete: false,
        ),
        isTrue,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.healthHub,
          isGuest: false,
          isAuthenticated: true,
          isProfileComplete: false,
        ),
        isTrue,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.bloodHub,
          isGuest: false,
          isAuthenticated: true,
          isProfileComplete: false,
        ),
        isFalse,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.chat,
          isGuest: false,
          isAuthenticated: true,
          isProfileComplete: false,
        ),
        isFalse,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.community,
          isGuest: false,
          isAuthenticated: true,
          isProfileComplete: false,
        ),
        isFalse,
      );

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.profile,
          isGuest: false,
          isAuthenticated: true,
          isProfileComplete: false,
        ),
        isFalse,
      );
    });

    test('Complete logged-in user: all features unlocked', () {
      for (final feature in AccessFeature.values) {
        expect(
          AccessGuard.canAccess(
            feature: feature,
            isGuest: false,
            isAuthenticated: true,
            isProfileComplete: true,
          ),
          isTrue,
          reason: 'Expected $feature to be accessible for complete user',
        );
      }
    });

    test('Unauthenticated non-guest: all features locked', () {
      for (final feature in AccessFeature.values) {
        expect(
          AccessGuard.canAccess(
            feature: feature,
            isGuest: false,
            isAuthenticated: false,
            isProfileComplete: false,
          ),
          isFalse,
          reason: 'Expected $feature to be locked for unauthenticated non-guest',
        );
      }
    });
  });

  group('AccessGuard Riverpod container integration tests', () {
    test('Container with isGuestProvider = true reflects guest access', () {
      final container = ProviderContainer(
        overrides: [
          isGuestProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      final isGuest = container.read(isGuestProvider);
      expect(isGuest, isTrue);

      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.feed,
          isGuest: isGuest,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isTrue,
      );
      expect(
        AccessGuard.canAccess(
          feature: AccessFeature.bloodHub,
          isGuest: isGuest,
          isAuthenticated: false,
          isProfileComplete: false,
        ),
        isFalse,
      );
    });
  });
}

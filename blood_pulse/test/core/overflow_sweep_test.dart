// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Target Screens
import 'package:blood_pulse/features/health_hub/presentation/screens/recovery_aftercare_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/science_of_blood_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/donation_guide_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/blood_compatibility_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_accessories_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/health_calculators_screen.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/resources_hub_screen.dart';
import 'package:blood_pulse/features/guest/presentation/screens/guest_welcome_screen.dart';
import 'package:blood_pulse/features/auth/presentation/screens/language_selection_screen.dart';
import 'package:blood_pulse/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:blood_pulse/features/auth/presentation/screens/login_screen.dart';
import 'package:blood_pulse/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:blood_pulse/features/settings/presentation/screens/settings_screen.dart';
import 'package:blood_pulse/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:blood_pulse/features/communities/presentation/widgets/register_club_form_view.dart';
import 'package:blood_pulse/features/blood_hub/presentation/screens/poster_generator_screen.dart';
import 'package:blood_pulse/features/blood_request/presentation/screens/emergency_request_screen.dart';
import 'package:blood_pulse/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:blood_pulse/features/assistant/presentation/screens/assistant_screen.dart';

import 'package:blood_pulse/features/assistant/presentation/providers/assistant_provider.dart';
import 'package:blood_pulse/features/assistant/domain/models/assistant_message_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:blood_pulse/core/theme/app_spacing.dart';

class _FakeAssistantSweepNotifier extends StateNotifier<AssistantState>
    implements AssistantNotifier {
  _FakeAssistantSweepNotifier()
      : super(AssistantState(
          messages: [],
          isSending: false,
          isLoading: false,
          consentGiven: true,
          isFirstRun: false,
        ));

  @override
  Future<void> sendMessage(String text, String locale, {String? screenContext}) async {}

  @override
  Future<void> sendFeedback(AssistantMessage message, String rating, {String? reason, String? note}) async {}

  @override
  Future<void> submitHandoff(String subject, String message, String preference) async {}

  @override
  Future<void> saveConsent(bool consent) async {}

  @override
  Future<void> clearChat() async {}
}

void main() {
  const List<Size> testSizes = [
    Size(320, 640),
    Size(360, 800),
    Size(412, 915),
    Size(600, 960),
  ];

  const List<double> textScales = [1.0, 1.3];

  final Map<String, Widget Function()> allScreens = {
    'RecoveryAftercareScreen': () => const RecoveryAftercareScreen(),
    'ScienceOfBloodScreen': () => const ScienceOfBloodScreen(),
    'DonationGuideScreen': () => const DonationGuideScreen(),
    'BloodCompatibilityScreen': () => const BloodCompatibilityScreen(),
    'HealthAccessoriesScreen': () => const HealthAccessoriesScreen(),
    'HealthCalculatorsScreen': () => const HealthCalculatorsScreen(),
    'ResourcesHubScreen': () => const ResourcesHubScreen(),
    'GuestWelcomeScreen': () => GuestWelcomeScreen(
      mapDataFetcher: () async => {'total_donors': 0, 'cells': <Map<String, dynamic>>[]},
      locationResolver: () async => (
        center: const LatLng(23.6850, 90.3563),
        zoom: 7.0,
        statusMessage: 'Location off — showing Bangladesh',
      ),
    ),
    'LanguageSelectionScreen': () => const LanguageSelectionScreen(),
    'OnboardingScreen': () => const OnboardingScreen(),
    'LoginScreen': () => const LoginScreen(),
    'ForgotPasswordScreen': () => const ForgotPasswordScreen(),
    'SettingsScreen': () => const SettingsScreen(),
    'PrivacyPolicyScreen': () => const PrivacyPolicyScreen(),
    'RegisterClubFormView': () => const RegisterClubFormView(),
    'PosterGeneratorScreen': () => const PosterGeneratorScreen(),
    'EmergencyRequestScreen': () => const EmergencyRequestScreen(),
    'NotificationCenterScreen': () => const NotificationCenterScreen(),
    'AssistantScreen': () => const AssistantScreen(),
  };

  group('Automated Full-App Overflow Sweep (Zero RenderFlex Overflow Guarantee)', () {
    for (final size in testSizes) {
      for (final textScale in textScales) {
        for (final entry in allScreens.entries) {
          testWidgets(
            '${entry.key} renders without overflow at ${size.width.toInt()}x${size.height.toInt()} (scale: $textScale)',
            (WidgetTester tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
              });

              FlutterErrorDetails? capturedDetails;
              final oldHandler = FlutterError.onError;
              FlutterError.onError = (details) {
                capturedDetails = details;
                oldHandler?.call(details);
              };

              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    assistantProvider.overrideWith(
                      (ref) => _FakeAssistantSweepNotifier(),
                    ),
                  ],
                  child: MaterialApp(
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: size,
                        textScaler: TextScaler.linear(textScale),
                      ),
                      child: entry.value(),
                    ),
                  ),
                ),
              );

              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
              FlutterError.onError = oldHandler;

              final err = tester.takeException();
              if (err != null) {
                // ignore: avoid_print
                print('TEST_FAIL: ${entry.key} at ${size.width}x${size.height} (scale: $textScale):');
                if (capturedDetails != null) {
                  // ignore: avoid_print
                  print(capturedDetails.toString());
                } else if (err is FlutterError) {
                  // ignore: avoid_print
                  print(err.toStringDeep());
                } else {
                  // ignore: avoid_print
                  print('  $err');
                }
              }
              expect(err, isNull);
            },
          );
        }
      }
    }
  });

  group('Responsive Foundation Component Tests', () {
    testWidgets('ResponsiveRow switches to column on narrow viewport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ResponsiveRow(
                breakpoint: 340,
                children: const [
                  Text('Item 1'),
                  Text('Item 2'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Column), findsOneWidget);
    });

    testWidgets('AppButton enforces min 48dp touch target and fits text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              onPressed: () {},
              label: 'Very Long Action Button Label That Must Not Overflow',
            ),
          ),
        ),
      );
      final buttonSize = tester.getSize(find.byType(AppButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
      expect(tester.takeException(), isNull);
    });
  });
}

// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router_notifier.dart';

// Auth
import '../splash_video_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/language_selection_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/verify_otp_reset_screen.dart';
import '../features/auth/presentation/screens/registration_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';

// Main Shell & Emergency Request
import '../features/shell/presentation/screens/main_shell_screen.dart';
import '../features/blood_request/presentation/screens/emergency_request_screen.dart';

// Notifications & Chat
import '../features/notifications/presentation/screens/notification_center_screen.dart';
import '../views/chat/chat_screen.dart';
import '../features/assistant/presentation/screens/assistant_screen.dart';
import '../features/donor/presentation/screens/donor_map_screen.dart';
import '../features/blood_request/presentation/screens/identity_verification_screen.dart';
import '../features/donor/presentation/screens/live_dispatch_screen.dart';

// Admin Screens
import '../features/admin/admin_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';

// Blood Hub v2 Screens
import '../features/blood_hub/presentation/screens/blood_hub_search_screen.dart';
import '../features/blood_hub/presentation/screens/direct_request_screen.dart';
import '../features/blood_hub/presentation/screens/personal_emergency_screen.dart';
import '../features/blood_hub/presentation/screens/emergency_hub_screen.dart';
import '../features/blood_hub/presentation/screens/journey_detail_screen.dart';
import '../features/blood_hub/presentation/screens/standby_offer_screen.dart';
import '../features/blood_hub/presentation/screens/national_emergency_screen.dart';
import '../features/blood_hub/presentation/screens/journey_list_screen.dart';

// Health Hub 7 Sub-Screens
import '../features/health_hub/presentation/screens/ai_report_analysis_screen.dart';
import '../features/health_hub/presentation/screens/health_calculators_screen.dart';
import '../features/health_hub/presentation/screens/science_of_blood_screen.dart';
import '../features/health_hub/presentation/screens/blood_compatibility_screen.dart';
import '../features/health_hub/presentation/screens/donation_guide_screen.dart';
import '../features/health_hub/presentation/screens/resources_hub_screen.dart';
import '../features/health_hub/presentation/screens/recovery_aftercare_screen.dart';
import '../features/health_hub/presentation/screens/health_accessories_screen.dart';

// Community Screens
import '../features/communities/presentation/widgets/register_club_form_view.dart';
import '../features/communities/presentation/widgets/local_club_profile_view.dart';
import '../features/communities/presentation/widgets/division_detail_screen.dart';
import '../features/communities/domain/models/community_models.dart';

// Profile & Settings Screens
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/user_profile_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/privacy_policy_screen.dart';
import 'widgets/blood_pulse_app_bar.dart';

/// Standalone profile screen rendered when user taps the top-bar avatar.
/// Fixes GoException: no routes for location: /profile
class _StandaloneProfileScreen extends StatelessWidget {
  const _StandaloneProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: BloodPulseAppBar(
        showBackButton: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
      ),
      body: const ProfileView(),
    );
  }
}





final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirectLogic,
    routes: [
    // ── Auth ──────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashVideoScreen(),
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) {
        final stepParam = state.uri.queryParameters['step'];
        final step = stepParam != null ? int.tryParse(stepParam) ?? 0 : 0;
        return OnboardingScreen(initialStep: step);
      },
    ),
    GoRoute(
      path: '/language',
      builder: (context, state) => const LanguageSelectionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final email = state.extra as String? ?? '';
        if (email.isEmpty) return const ForgotPasswordScreen();
        return VerifyOtpResetScreen(email: email);
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegistrationScreen(),
    ),
    GoRoute(
      path: '/otp-verify',
      builder: (context, state) => const OtpVerificationScreen(),
    ),

    // ── Main Shell (5-Tabs) ───────────────────────────────────────────────────
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const MainShellScreen(),
    ),
    GoRoute(
      path: '/feed',
      builder: (context, state) => const MainShellScreen(),
    ),

    // ── Blood Hub v2 Routes ───────────────────────────────────────────────────
    // /blood-hub — redirects to /dashboard (MainShellScreen handles tab via shellTabProvider)
    GoRoute(
      path: '/blood-hub',
      redirect: (context, state) => '/dashboard',
    ),
    // /blood-hub/search — Donor Search Results + fuzzed OSM map
    GoRoute(
      path: '/blood-hub/search',
      builder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFFFFF8F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF2B2B2B)),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/blood-hub'),
          ),
          title: const Text(
            'Search Donors',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          centerTitle: false,
        ),
        body: const BloodHubSearchScreen(),
      ),
    ),
    // /blood-hub/request/direct — Priority Requisition form
    GoRoute(
      path: '/blood-hub/request/direct',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF2B2B2B)),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/blood-hub'),
            ),
            title: const Text(
              'Blood Request',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            centerTitle: false,
          ),
          body: DirectRequestScreen(
            prefillBloodGroup: extra?['prefill_blood_group'] as String?,
            prefillComponent: extra?['prefill_component'] as String?,
            prefillDistrict: extra?['prefill_district'] as String?,
            mode: extra?['mode'] as String?,
          ),
        );
      },
    ),
    // /emergency — Emergency Hub (2-card: national + personal)
    GoRoute(
      path: '/emergency',
      builder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFFFFF8F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF2B2B2B)),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/blood-hub'),
          ),
          title: const Text(
            'Emergency Hub',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          centerTitle: false,
        ),
        body: const EmergencyHubScreen(),
      ),
    ),
    // /emergency/national — Disaster Overview (Prompt 4)
    GoRoute(
      path: '/emergency/national',
      builder: (context, state) => const NationalEmergencyScreen(),
    ),

    // /emergency/personal — Personal Emergency Request form (Prompt 3B scope)
    GoRoute(
      path: '/emergency/personal',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF2B2B2B)),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/emergency'),
            ),
            title: const Text(
              'Personal Emergency',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
          body: PersonalEmergencyScreen(
            prefillBloodGroup: extra?['prefill_blood_group'] as String?,
            prefillComponent: extra?['prefill_component'] as String?,
            prefillDistrict: extra?['prefill_district'] as String?,
            mode: extra?['mode'] as String?,
          ),
        );
      },
    ),
    // /journeys — Active Requests list (Prompt 5)
    GoRoute(
      path: '/journeys',
      builder: (context, state) => const JourneyListScreen(),
    ),
    // /journeys/:id — Journey Detail (Prompt 4) — role-aware two-sided tracking
    GoRoute(
      path: '/journeys/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final id = int.tryParse(idStr) ?? 0;
        return JourneyDetailScreen(journeyId: id);
      },
    ),
    // /standby/:offerId — Standby Donor Alert (Prompt 4)
    GoRoute(
      path: '/standby/:offerId',
      builder: (context, state) {
        final idStr = state.pathParameters['offerId'] ?? '0';
        final offerId = int.tryParse(idStr) ?? 0;
        return StandbyOfferScreen(offerId: offerId);
      },
    ),
    // /identity/verify — Email OTP verification (Prompt 5 scope; bridges to existing)
    GoRoute(
      path: '/identity/verify',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF2B2B2B)),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/blood-hub'),
            ),
            title: const Text(
              'Identity Verification',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
          body: IdentityVerificationScreen(
            patientName: extra?['patientName'] as String?,
            bloodGroup: extra?['bloodGroup'] as String?,
            urgencyLevel: extra?['urgencyLevel'] as String?,
            hospitalLocation: extra?['hospitalLocation'] as String?,
            contactNumber: extra?['contactNumber'] as String?,
            returnRoute:
                extra?['returnRoute'] as String? ?? '/blood-hub',
          ),
        );
      },
    ),



    // ── Notifications ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterScreen(),
    ),

    // ── Real-Time WhatsApp-Style Emergency Chat ───────────────────────────────
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final extra = state.extra;
        String chatRoomId = 'general_chat';
        String chatRecipientName = 'Emergency Contact';
        String bloodGroup = '';
        String recipientId = '';

        if (extra is Map<String, dynamic>) {
          chatRecipientName = extra['chatRecipientName'] as String? ??
              extra['recipientName'] as String? ??
              chatRecipientName;
          bloodGroup = extra['bloodGroup'] as String? ?? bloodGroup;
          recipientId = extra['recipientId'] as String? ??
              extra['receiverId'] as String? ??
              extra['senderId'] as String? ??
              '';
          chatRoomId = extra['chatRoomId'] as String? ??
              (recipientId.isNotEmpty
                  ? 'chat_$recipientId'
                  : 'chat_${chatRecipientName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}');
        } else if (extra is String) {
          chatRoomId = extra;
          recipientId = extra;
        } else {
          chatRecipientName = state.uri.queryParameters['name'] ?? chatRecipientName;
          bloodGroup = state.uri.queryParameters['bloodGroup'] ?? bloodGroup;
          recipientId = state.uri.queryParameters['recipientId'] ?? '';
          chatRoomId = state.uri.queryParameters['roomId'] ??
              (recipientId.isNotEmpty
                  ? 'chat_$recipientId'
                  : 'chat_${chatRecipientName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}');
        }

        return ChatScreen(
          chatRoomId: chatRoomId,
          chatRecipientName: chatRecipientName,
          bloodGroup: bloodGroup,
          recipientId: recipientId,
        );
      },
    ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) {
          final contextData = state.extra as String?;
          return AssistantScreen(screenContext: contextData);
        },
      ),

    // ── OpenStreetMap Donor Mapping ───────────────────────────────────────────
    GoRoute(
      path: '/map',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'];
        final extra = state.extra as Map<String, dynamic>?;
        return DonorMapScreen(
          initialMode: mode ?? extra?['mode'] as String?,
          patientName: extra?['patientName'] as String?,
          hospitalName: extra?['hospitalName'] as String?,
          bloodGroup: extra?['bloodGroup'] as String?,
          donorName: extra?['donorName'] as String?,
          donorPhone: extra?['donorPhone'] as String?,
          destinationLat: (extra?['destinationLat'] as num?)?.toDouble(),
          destinationLng: (extra?['destinationLng'] as num?)?.toDouble(),
        );
      },
    ),

    // ── Emergency Blood Request & Profile Completion ────────────────────────
    GoRoute(
      path: '/emergency-request',
      builder: (context, state) => const EmergencyRequestScreen(),
    ),
    GoRoute(
      path: '/create-request',
      builder: (context, state) => const EmergencyRequestScreen(),
    ),

    GoRoute(
      path: '/identity-verification',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return IdentityVerificationScreen(
          patientName: extra?['patientName'] as String?,
          bloodGroup: extra?['bloodGroup'] as String?,
          urgencyLevel: extra?['urgencyLevel'] as String?,
          hospitalLocation: extra?['hospitalLocation'] as String?,
          contactNumber: extra?['contactNumber'] as String?,
          returnRoute: extra?['returnRoute'] as String? ?? '/live-dispatch',
        );
      },
    ),
    GoRoute(
      path: '/live-dispatch',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return LiveDispatchScreen(
          patientName: extra?['patientName'] as String? ?? 'Requester',
          hospitalName: extra?['hospitalName'] as String? ?? 'Medical Center',
          bloodGroup: extra?['bloodGroup'] as String? ?? '',
          donorName: extra?['donorName'] as String? ?? 'Matched Donor',
          donorPhone: extra?['donorPhone'] as String? ?? '',
          initialRole: extra?['role'] == 'donor' ? DispatchRole.donor : DispatchRole.requester,
        );
      },
    ),

    // ── Admin Panel ───────────────────────────────────────────────────────────
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboardScreen(),
    ),

    // ── Health Hub 7 Dedicated Sub-Screens ────────────────────────────────────
    GoRoute(
      path: '/health-hub/ai-report',
      builder: (context, state) => const AiReportAnalysisScreen(),
    ),
    GoRoute(
      path: '/ai-report-analysis',
      builder: (context, state) => const AiReportAnalysisScreen(),
    ),
    GoRoute(
      path: '/faq',
      builder: (context, state) => const DonationGuideScreen(),
    ),
    GoRoute(
      path: '/faq/weight',
      builder: (context, state) => const DonationGuideScreen(),
    ),
    GoRoute(
      path: '/faq/interval',
      builder: (context, state) => const DonationGuideScreen(),
    ),
    GoRoute(
      path: '/health-hub/calculators',
      builder: (context, state) => const HealthCalculatorsScreen(),
    ),
    GoRoute(
      path: '/health-hub/science-of-blood',
      builder: (context, state) => const ScienceOfBloodScreen(),
    ),
    GoRoute(
      path: '/health-hub/compatibility',
      builder: (context, state) => const BloodCompatibilityScreen(),
    ),
    GoRoute(
      path: '/health-hub/donation-guide',
      builder: (context, state) => const DonationGuideScreen(),
    ),
    GoRoute(
      path: '/health-hub/resources',
      builder: (context, state) => const ResourcesHubScreen(),
    ),
    GoRoute(
      path: '/health-hub/recovery',
      builder: (context, state) => const RecoveryAftercareScreen(),
    ),
    GoRoute(
      path: '/health-hub/accessories',
      builder: (context, state) => const HealthAccessoriesScreen(),
    ),
    // ── Community Screens ─────────────────────────────────────────────────────
    GoRoute(
      path: '/division-view',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final name = extra?['name'] as String? ?? 'Dhaka';
        final id = extra?['id'] as int?;
        return DivisionDetailScreen(divisionName: name, divisionId: id);
      },
    ),
    GoRoute(
      path: '/club-profile',
      builder: (context, state) {
        final club = state.extra as LocalClub? ??
            LocalClub(
              id: 1,
              name: 'Uttara Blood Warriors',
              establishedYear: 2015,
              slogan: 'You give today, they live today',
              description:
                  'Dedicated to saving lives in Uttara since 2015, the Uttara Blood Warriors is a community-driven network of altruistic donors focused on ensuring a safe and reliable blood supply.',
              divisionId: 1,
              divisionName: 'Dhaka',
              districtId: 1,
              districtName: 'Dhaka',
              upazilaId: 1,
              upazilaName: 'Uttara',
              presidentName: 'Dr. Rafiqul Islam',
              contactNumber: '+880 1711-234567',
              totalDonors: '1.2k+',
              activeDonors: '850+',
              contributions: '5k+',
              isVerified: true,
              executiveMembers: [],
            );
        return LocalClubProfileView(club: club);
      },
    ),
    GoRoute(
      path: '/communities/club/:id',
      builder: (context, state) {
        final club = state.extra as LocalClub;
        return LocalClubProfileView(club: club);
      },
    ),
    GoRoute(
      path: '/register-club',
      builder: (context, state) => const RegisterClubFormView(),
    ),
    GoRoute(
      path: '/communities/register-club',
      builder: (context, state) => const RegisterClubFormView(),
    ),

    // ── Profile ───────────────────────────────────────────────────────────────
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    // /profile — standalone screen for top-bar avatar tap
    // Fixes: GoException: no routes for location: /profile
    GoRoute(
      path: '/profile',
      builder: (context, state) => const _StandaloneProfileScreen(),
    ),
    // /settings — Settings & Security Screen
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // /privacy-policy — Privacy Policy Screen
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
  ],
  );
});





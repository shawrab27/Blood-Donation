import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Auth
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/registration_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';

// Main Shell & Emergency Request
import '../features/shell/presentation/screens/main_shell_screen.dart';
import '../features/blood_request/presentation/screens/emergency_request_screen.dart';

// Notifications & Chat
import '../features/notifications/presentation/screens/notification_center_screen.dart';
import '../views/chat/chat_screen.dart';
import '../features/donor/presentation/screens/donor_map_screen.dart';

// Admin Screens
import '../features/admin/admin_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';

// Health Hub 7 Sub-Screens
import '../features/health_hub/presentation/screens/ai_report_analysis_screen.dart';
import '../features/health_hub/presentation/screens/health_calculators_screen.dart';
import '../features/health_hub/presentation/screens/science_of_blood_screen.dart';
import '../features/health_hub/presentation/screens/blood_compatibility_screen.dart';
import '../features/health_hub/presentation/screens/donation_guide_screen.dart';
import '../features/health_hub/presentation/screens/resources_hub_screen.dart';
import '../features/health_hub/presentation/screens/recovery_aftercare_screen.dart';

// Community Screens
import '../features/communities/presentation/widgets/register_club_form_view.dart';
import '../features/communities/presentation/widgets/local_club_profile_view.dart';
import '../features/communities/presentation/widgets/division_detail_screen.dart';
import '../features/communities/domain/models/community_models.dart';

// Profile Screens
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/complete_profile_screen.dart';
import '../features/profile/presentation/screens/user_profile_screen.dart';
import 'widgets/blood_pulse_app_bar.dart';

/// Standalone profile screen rendered when user taps the top-bar avatar.
/// Fixes GoException: no routes for location: /profile
class _StandaloneProfileScreen extends StatelessWidget {
  const _StandaloneProfileScreen({super.key});

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

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // ── Auth ──────────────────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
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
        String chatRoomId = 'sarah_jenkins_o_minus';
        String chatRecipientName = 'Sarah Jenkins';
        String bloodGroup = 'O-';

        if (extra is Map<String, dynamic>) {
          chatRoomId = extra['chatRoomId'] as String? ?? chatRoomId;
          chatRecipientName = extra['chatRecipientName'] as String? ??
              extra['recipientName'] as String? ??
              chatRecipientName;
          bloodGroup = extra['bloodGroup'] as String? ?? bloodGroup;
        } else if (extra is String) {
          chatRoomId = extra;
        } else {
          chatRoomId = state.uri.queryParameters['roomId'] ?? chatRoomId;
          chatRecipientName = state.uri.queryParameters['name'] ?? chatRecipientName;
          bloodGroup = state.uri.queryParameters['bloodGroup'] ?? bloodGroup;
        }

        return ChatScreen(
          chatRoomId: chatRoomId,
          chatRecipientName: chatRecipientName,
          bloodGroup: bloodGroup,
        );
      },
    ),

    // ── OpenStreetMap Donor Mapping ───────────────────────────────────────────
    GoRoute(
      path: '/map',
      builder: (context, state) => const DonorMapScreen(),
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
      path: '/complete-profile',
      builder: (context, state) => const CompleteProfileScreen(),
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
  ],
);

import 'package:go_router/go_router.dart';

// Auth
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/registration_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';

// Main Shell & Emergency Request
import '../features/shell/presentation/screens/responsive_app_shell.dart';
import '../features/blood_request/presentation/screens/emergency_request_screen.dart';

// Notifications & Chat
import '../features/notifications/presentation/screens/notification_center_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
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
      builder: (context, state) => const ResponsiveAppShell(),
    ),

    // ── Notifications ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterScreen(),
    ),

    // ── Real-Time WhatsApp-Style Emergency Chat ───────────────────────────────
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatScreen(),
    ),

    // ── OpenStreetMap Donor Mapping ───────────────────────────────────────────
    GoRoute(
      path: '/map',
      builder: (context, state) => const DonorMapScreen(),
    ),

    // ── Emergency Blood Request ───────────────────────────────────────────────
    GoRoute(
      path: '/emergency-request',
      builder: (context, state) => const EmergencyRequestScreen(),
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
  ],
);
